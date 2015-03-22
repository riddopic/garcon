# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: zip_file
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

require 'find'
require_relative '../files/lib/garcon'

class Chef
  class Resource
    class ZipFile < Chef::Resource
      include Garcon

      # Chef attributes
      identity_attr :path
      provides :zip_file
      state_attrs :checksum, :owner, :group, :mode

      # Actions
      actions :zip, :unzip
      default_action :unzip

      # Attributes
      attribute :path,
        kind_of: String,
        name_attribute: true
      attribute :source,
        kind_of: [String, URI::HTTP],
        required: true
      attribute :remove_after,
        kind_of: [TrueClass, FalseClass],
        default: false
      attribute :overwrite,
        kind_of: [TrueClass, FalseClass],
        default: false
      attribute :checksum,
        kind_of: String,
        default: nil
      attribute :owner,
        kind_of: [String, Integer]
      attribute :group,
        kind_of: [String, Integer]
      attribute :mode,
        kind_of: Integer
      attribute :check_cert,
        kind_of: [TrueClass, FalseClass]
      attribute :header,
        kind_of: String
    end
  end

  class Provider
    class ZipFile < Chef::Provider
      include Chef::Mixin::EnforceOwnershipAndPermissions
      include Garcon

      def initialize(new_resource, run_context)
        super
        do_prerequisite unless defined?(Zip)
      end

      # Boolean indicating if WhyRun is supported by this provider.
      #
      # @return [TrueClass, FalseClass]
      # @api private
      def whyrun_supported?
        true
      end

      # Load and return the current resource.
      #
      # @return [Chef::Provider::ZipFile]
      # @api private
      def load_current_resource
        @current_resource ||= Chef::Resource::ZipFile.new(new_resource.name)
        @current_resource
      end

      def action_unzip
        monitor.synchronize do
          converge_by "Unzip to #{new_resource.path}" do
            zipfile   = cached_file(new_resource.source, new_resource.checksum)
            overwrite = new_resource.overwrite
            Zip::File.open(zipfile) do |zip|
              zip.each do |entry|
                path = ::File.join(new_resource.path, entry.name)
                FileUtils.mkdir_p(::File.dirname(path))
                if overwrite && ::File.exists?(path) && !::File.directory?(path)
                  FileUtils.rm(path)
                end
                zip.extract(entry, path)
              end
            end
            do_acl_changes
            ::File.unlink(zipfile) if new_resource.remove_after
            new_resource.updated_by_last_action(true)
          end
        end
      end

      def action_zip
        monitor.synchronize do
          if ::File.exists?(new_resource.path) && !new_resource.overwrite
            Chef::Log.info "#{new_resource.path} already exists - nothing to do"
          else
            if ::File.exists?(new_resource.path)
              ::File.unlink(new_resource.path)
            end
            if ::File.directory?(new_resource.source)
              converge_by "Zip #{new_resource.source}" do
                z = Zip::File.new(new_resource.path, true)
                Find.find(new_resource.source) do |f|
                  next if f == new_resource.source
                  zip_fname = f.sub(new_resource.source, '')
                  z.add(zip_fname, f)
                end
                z.close
                do_acl_changes
                new_resource.updated_by_last_action(true)
              end
            else
              Chef::Log.info 'a valid directory must be specified for ziping'
            end
          end
        end
      end

      # Implementation components *should* follow symlinks when managing access
      # control (e.g., use chmod instead of lchmod even if the path we're
      # managing is a symlink).
      def manage_symlink_access?
        false
      end

      private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

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

      # Ensure all prerequisite software is installed.
      #
      # @return [undefined]
      # @api private
      def do_prerequisite
        require 'zip'
      rescue LoadError
        gem_rubyzip.run_action(:install)
        Chef::Recipe.send(:require, 'zip')
      end

      def gem_rubyzip
        @gem_rubyzip ||= Chef::Resource::ChefGem.new('rubyzip', run_context)
        @gem_rubyzip.compile_time(false) if respond_to?(:compile_time)
        @gem_rubyzip.run_action(:nothing)
        @gem_rubyzip
      end

      # Cache a file locally in `Chef::Config[:file_cache_path]`.
      # @note The file is gargbage collected at the end of a run.
      #
      # @param source [String, URI]
      #   source file path
      # @param checksum [String]
      #   the SHA-256 checksum of the file
      #
      # @return [String]
      #   path to the cached file
      #
      # @api private
      def cached_file(src, checksum = nil)
        if src =~ URI::ABS_URI &&
          %w[ftp http https].include?(URI.parse(src).scheme)
          file = ::File.basename(URI.unescape(URI.parse(src).path))
          cache_file_path = file_cache_path(file)

          download file do
            source        src
            # backup        false
            checksum      checksum if checksum
            directory     file_cache_path
            check_cert    false
            header        new_resource.header if new_resource.header
            action       :nothing
          end.run_action :create
        else
          cache_file_path = src
        end
        cache_file_path
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
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :centos,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :oracle,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :redhat,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)

# Chef::Platform mapping for resource and providers
#
# @return [undefined]
#
# @api private.
Chef::Platform.set(
  platform: :scientific,
  resource: :zip_file,
  provider:  Chef::Provider::ZipFile
)
