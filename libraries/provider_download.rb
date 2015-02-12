# encoding: UTF-8
#
# Cookbook Name:: odsee
# Provider:: ldap_entry
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

# require 'chef/scan_access_control'

class Chef::Provider::Download < Chef::Provider
  include Chef::Mixin::EnforceOwnershipAndPermissions
  include Chef::Mixin::Checksum
  include Garcon

  provides :download, os: 'linux'

  def initialize(new_resource, run_context)
    super
    do_prerequisite unless installed?('aria2c')
  end

  # Boolean indicating if WhyRun is supported by this provider
  #
  # @return [TrueClass, FalseClass]
  #
  # @api private
  def whyrun_supported?
    true
  end

  # Load and return the current resource.
  #
  # @return [Chef::Resource::LdapEntry]
  #
  # @api private
  def load_current_resource
    @current_resource = Chef::Resource::Download.new(new_resource.name)
    @current_resource.path(new_resource.path)
    if (@current_resource.exists = ::File.exist?(@current_resource.path))
      @current_resource.checksum(checksum(@current_resource.path))
      load_resource_attributes_from_file(@current_resource)
    else
      @current_resource.checksum(nil)
    end
    @current_resource
  end

  def action_create
    if exists_with_valid_checksum? && !access_controls.requires_changes?
      Chef::Log.info "#{new_resource.path} already exists - nothing to do"
    elsif exists_with_valid_checksum? && access_controls.requires_changes?
      converge_by(access_controls.describe_changes) do
        access_controls.set_all
      end
      new_resource.updated_by_last_action(true)
    else
      converge_by "Download #{new_resource.source} to #{new_resource.path}" do
        backup unless ::File.symlink?(new_resource.path)
        do_download
      end
      do_acl_changes
      load_resource_attributes_from_file(@new_resource)
      new_resource.updated_by_last_action(true)
    end
  end
  alias_method :action_create_if_missing, :action_create

  def action_delete
    if @current_resource.exists?
      converge_by "Delete #{new_resource.path}" do
        backup unless ::File.symlink?(new_resource.path)
        ::File.delete(new_resource.path)
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} does not exists - nothing to do"
    end
  end

  def action_touch
    if @current_resource.exists?
      converge_by "Update utime on #{new_resource.path}" do
        time = Time.now
        ::File.utime(time, time, new_resource.path)
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} does not exists - nothing to do"
    end
  end

  # Implementation components *should* follow symlinks when managing access
  # control (e.g., use chmod instead of lchmod even if the path we're
  # managing is a symlink).
  def manage_symlink_access?
    false
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  # Boolean, returns true if the resource exists and a checksum was supplied and
  # the supplied checksum is a match for the resource checksum, otherwise false
  #
  # @return [TrueClass, FalseClass]
  # @api private
  def exists_with_valid_checksum?
    (@current_resource.exists? && !new_resource.checksum.nil?) &&
    (@current_resource.checksum == new_resource.checksum)
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

  # Reads Access Control Settings on a file and writes them out to a resource,
  # attempting to match the style used by the new resource, that is, if users
  # are specified with usernames in new_resource, then the uids from stat will
  # be looked up and usernames will
  # be added to current_resource.
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
      new_resource._?(:checksum, '--checksum=sha-256=').gsub(/\s+/, '')
    end
    aria2c(checksum,
      new_resource._?(:path,        '-o'),
      new_resource._?(:directory,   '-d'),
      new_resource._?(:split_size,  '-s'),
      new_resource._?(:connections, '-x'),
      new_resource._?(:check_cert,  '--check-certificate=false'),
      new_resource.source)
  end

  def do_prerequisite
    package('gnutls')   { action :nothing }.run_action(:install)
    chef_gem('rubyzip') { action :nothing }.run_action(:install)
    Chef::Recipe.send(:require, 'zip')
    unless installed?('aria2c')
      begin
        yum = Chef::Resource::YumRepository.new('garcon', run_context)
        yum.mirrorlist node[:garcon][:repo][:mirrorlist]
        yum.gpgcheck   node[:garcon][:repo][:gpgcheck]
        yum.gpgkey     node[:garcon][:repo][:gpgkey]
        yum.run_action(:create)
        package('aria2') { action :nothing }.run_action(:install)
      ensure
        yum.run_action(:delete)
      end
    end
  end

  # Command line executioner for running aria2c
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
  [:aria2c].each do |cmd|
    define_method(cmd) do |*args|
      (run ||= []) << which(cmd.to_s) << args
      Chef::Log.info shell_out!(run.flatten.join(' ')).stdout
    end
  end

  # Backup the file before overwriting or replacing it unless
  # `new_resource.backup` is `false`
  #
  # @return [undefined]
  # @api private
  def backup(file = nil)
    Chef::Util::Backup.new(new_resource, file).backup!
  end
end
