# encoding: UTF-8
#
# Cookbook Name:: garcon
# Resources:: download
#
# Author:    Stefano Harding <riddopic@gmail.com>
# License:   Apache License, Version 2.0
# Copyright: (C) 2014-2015 Stefano Harding
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require_relative '../files/lib/garcon'

class Chef
  class Resource
    class Download < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :path
      provides :download
      state_attrs :checksum, :owner, :group, :mode

      # Actions
      actions :create, :create_if_missing, :delete, :touch
      default_action :create

      # Attributes
      attribute :path,
        kind_of: String,
        name_attribute: true
      attribute :directory,
        kind_of: String,
        default: nil
      attribute :backup,
        kind_of: [Integer, FalseClass],
        default: 5
      attribute :checksum,
        kind_of: String,
        default: nil
      attribute :split_size,
        kind_of: Integer,
        default: 5
      attribute :connections,
        kind_of: Integer,
        default: 5
      attribute :owner,
        kind_of: [String, Integer],
        default: nil
      attribute :group,
        kind_of: [String, Integer],
        default: nil
      attribute :mode,
        kind_of: Integer,
        default: nil
      attribute :check_cert,
        kind_of: [TrueClass, FalseClass]
      attribute :header,
        kind_of: String
      attribute :source,
        kind_of: [String, URI::HTTP],
        callbacks: { source: ->(source) { validate_source(source) }},
        required: true

      # @!attribute [rw] installed
      #   @return [TrueClass, FalseClass] True if resource exists.
      attr_accessor :exist

      # Determine if the resource exists. This value is set by the provider
      # when the current resource is loaded.
      #
      # @see Dsccsetup#action_create
      #
      # @return [Boolean]
      #
      # @api public
      def exist?
        !!@exist
      end
    end
  end

  class Provider
    class Download < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Chef::Mixin::Checksum
      include Garcon::Retry
      include Garcon

      def initialize(name, run_context = nil)
        super
        @resource_name = :download
        @provider      = Chef::Provider::Download
        @ready         = AtomicBoolean.new(installed?('aria2c'))
        @lock          = ReadWriteLock.new

        ready! if !ready?
        poll(300) { ready? }
      end

      # Boolean indicating if WhyRun is supported by this provider
      #
      # @return [TrueClass, FalseClass]
      #
      # @api private
      def whyrun_supported?
        true
      end

      # Reload the resource state when something changes
      #
      # @return [undefined]
      #
      # @api private
      def load_new_resource_state
        if new_resource.exist.nil?
          new_resource.exist = @current_resource.exist
        end
      end

      # Load and return the current resource.
      #
      # @return [Chef::Provider::Download]
      #
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::Download.new(new_resource.name)
        @current_resource.path(new_resource.path)

        if ::File.exist?(@current_resource.path)
          @current_resource.checksum(checksum(@current_resource.path))
          if @current_resource.checksum == new_resource.checksum
            @current_resource.exist = true
          else
            @current_resource.exist = false
          end
        else
          @current_resource.exist = false
        end
        @current_resource
      end

      def action_create
        do_create
      end

      def action_create_if_missing
        do_create
      end

      def action_delete
        if current_resource.exist?
          converge_by "Delete #{new_resource.path}" do
            backup unless ::File.symlink?(new_resource.path)
            ::File.delete(new_resource.path)
          end
          new_resource.updated_by_last_action(true)
          load_new_resource_state
          @current_resource.exist = false
        else
          Chef::Log.debug "#{new_resource.path} does not exists - nothing to do"
        end
      end

      def action_touch
        if current_resource.exist?
          converge_by "Update utime on #{new_resource.path}" do
            time = Time.now
            ::File.utime(time, time, new_resource.path)
          end
          new_resource.updated_by_last_action(true)
          load_new_resource_state
          @current_resource.exist = true
        else
          Chef::Log.debug "#{new_resource.path} does not exists - nothing to do"
        end
      end

      # Implementation components *should* follow symlinks when managing access
      # control (e.g., use chmod instead of lchmod even if the path we're
      # managing is a symlink).
      def manage_symlink_access?
        false
      end

      private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def do_create
        if current_resource.exist? && !access_controls.requires_changes?
            Chef::Log.debug "#{new_resource} already exists - nothing to do"
        elsif current_resource.exist? && access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
          new_resource.updated_by_last_action(true)
        else
          converge_by "Download #{new_resource.path}" do
            backup unless ::File.symlink?(new_resource.path)
            do_download
          end
          do_acl_changes
          load_resource_attributes_from_file(new_resource)
          new_resource.updated_by_last_action(true)
          load_new_resource_state
          @current_resource.exist = true
        end
      end

      # Change file ownership and mode
      #
      # @return [undefined]
      # @api private
      def do_acl_changes
        if access_controls.requires_changes?
          converge_by(access_controls.describe_changes) do
            access_controls.set_all
          end
        end
      end

      # Reads Access Control Settings on a file and writes them out to a
      # resource, attempting to match the style used by the new resource, that
      # is, if users are specified with usernames in new_resource, then the
      # uids from stat will be looked up and usernames will be added to
      # current_resource.
      #
      # @return [undefined]
      # @api private
      def load_resource_attributes_from_file(resource)
        acl_scanner = Chef::ScanAccessControl.new(@new_resource, resource)
        # acl_scanner.set_all!
      end

      # Gather options and download file
      #
      # @return [undefined]
      # @api private
      def do_download
        checksum = if new_resource.checksum
          new_resource._?(:checksum, '--checksum=sha-256=').join
        end
        header = if new_resource.header
          "--header='#{new_resource._?(:header)[1]}'"
        end
        aria2(checksum, header,
          new_resource._?(:path,        '-o'),
          new_resource._?(:directory,   '-d'),
          new_resource._?(:split_size,  '-s'),
          new_resource._?(:connections, '-x'),
          new_resource._?(:check_cert,  '--check-certificate=false'),
          new_resource.source)
      end

      # Command line executioner for running aria2
      #
      # @param [String, Array] args
      #   Any additional arguments and/or operand
      # @return [Hash, self]
      #   `#stdout`, `#stderr`, `#status`, and `#exitstatus` will be populated
      #   with results of the command
      #
      # @raise [Errno::EACCES]
      #   When you are not privileged to execute the command
      # @raise [Errno::ENOENT]
      #   When the command is not available on the system (or in the $PATH)
      # @raise [Chef::Exceptions::CommandTimeout]
      #   When the command does not complete within timeout (default: 60s)
      #
      # @api private
      def aria2(*args)
        retrier(tries: 10, sleep: ->(n) { 4**n }) { installed?('aria2') }
        run = [which('aria2c')] << args.flatten.join(' ')
        Chef::Log.info shell_out!(run.flatten.join(' ')).stdout
      end

      # Backup the file before overwriting or replacing it unless
      # `new_resource.backup` is `false`
      #
      # @return [undefined]
      # @api private
      def backup(file = nil)
        Chef::Util::Backup.new(new_resource, file).backup!
      end

      def ready?
        @ready.value
      end

      def ready!
        return true if @ready.value == true
        @lock.with_write_lock { handle_prerequisites }
        installed?('aria2c') ? @ready.make_true : @ready.make_false
      end

      def handle_prerequisites
        pkg_gnutls
        pkg_aria2
      end

      def pkg_gnutls
        package 'gnutls' do
          retries       30
          retry_delay   10
        end.run_action :install
      end

      def yumrepo
        yum ||= Chef::Resource::YumRepository.new 'garcon', run_context
        yum.mirrorlist node[:garcon][:repo][:mirrorlist]
        yum.gpgcheck   node[:garcon][:repo][:gpgcheck]
        yum.gpgkey     node[:garcon][:repo][:gpgkey]
        yum.run_action(:nothing)
        yum
      end

      def pkg_aria2
        yumrepo.run_action(:create)
        package 'aria2' do
          retries       30
          retry_delay   10
        end.run_action :install
        yumrepo.run_action(:delete)
      end
    end
  end
end

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :amazon,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :download,
  provider:  Chef::Provider::Download
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :download,
  provider:  Chef::Provider::Download
)
