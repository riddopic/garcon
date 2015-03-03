# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: provider_zip_file
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

class Chef::Provider::ZipFile < Chef::Provider
  include Chef::Mixin::EnforceOwnershipAndPermissions
  include Garcon

  provides :zip_file, os: 'linux'

  def initialize(new_resource, run_context)
    super
    do_prerequisite unless defined?(Zip)
  end

  # Boolean indicating if WhyRun is supported by this provider.
  #
  # @return [TrueClass, FalseClass]
  #
  # @api private
  def whyrun_supported?
    true
  end

  # Load and return the current resource.
  #
  # @return [Chef::Provider::ZipFile]
  #
  # @api private
  def load_current_resource
    @current_resource = Chef::Resource::ZipFile.new(new_resource.name)
    @current_resource
  end

  # Unzip method
  #
  def action_unzip
    monitor.synchronize do
      converge_by "Unzip #{new_resource.source} to #{new_resource.path}" do
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

  # Zip mmethod
  #
  def action_zip
    monitor.synchronize do
      if ::File.exists?(new_resource.path) && !new_resource.overwrite
        Chef::Log.info "#{new_resource.path} already exists - nothing to do"
      else
        ::File.unlink(new_resource.path) if ::File.exists?(new_resource.path)
        if ::File.directory?(new_resource.source)
          converge_by "Zip #{new_resource.source} to #{new_resource.path}" do
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
    chef_gem 'rubyzip'
    Chef::Recipe.send(:require, 'zip')
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
    if src =~ URI::ABS_URI && %w[ftp http https].include?(URI.parse(src).scheme)
      file = ::File.basename(URI.unescape(URI.parse(src).path))
      cache_file_path = ::File.join(Chef::Config[:file_cache_path], file)

      Chef::Log.info "Caching file #{src} at #{cache_file_path}"
      dl = Chef::Resource::Download.new(file, run_context)
      dl.source     src
      dl.backup     false
      dl.checksum   checksum if checksum
      dl.directory  Chef::Config[:file_cache_path]
      dl.check_cert false
      dl.header     new_resource.header if new_resource.header
      dl.run_action(:create)

      # download file do
      #   source      src
      #   backup      false
      #   checksum    checksum if checksum
      #   directory   Chef::Config[:file_cache_path]
      #   check_cert  false
      #   header      new_resource.header if new_resource.header
      #   action     :create
      # end
    else
      cache_file_path = src
    end
    cache_file_path
  end
end
