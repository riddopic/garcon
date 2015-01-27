# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: provider_zip_file
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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

class Chef::Provider::ZipFile < Chef::Provider::LWRPBase
  include Chef::Mixin::EnforceOwnershipAndPermissions
  include Garcon::Helpers
  require 'find'

  use_inline_resources if defined?(:use_inline_resources)

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
  # @return [Chef::Provider::Dsccsetup]
  #
  # @api private
  def load_current_resource
    @current_resource ||= Chef::Resource::ZipFile.new(new_resource.name)
  end

  action :unzip do
    monitor.synchronize do
      converge_by "Unziping #{new_resource.source} to #{new_resource.path}" do
        zip_file = cached_file(new_resource.source, new_resource.checksum)
        overwrite = new_resource.overwrite
        Zip::File.open(zip_file) do |zip|
          zip.each do |entry|
            path = ::File.join(new_resource.path, entry.name)
            FileUtils.mkdir_p(::File.dirname(path))
            if overwrite && ::File.exists?(path) && !::File.directory?(path)
              FileUtils.rm(path)
            end
            zip.extract(entry, path)
          end
        end
        ::File.unlink(zip_file) if new_resource.remove_after
        do_acl_changes
        new_resource.updated_by_last_action(true)
      end
    end
  end

  action :zip do
    monitor.synchronize do
      if ::File.exists?(new_resource.path) && !new_resource.overwrite
        Chef::Log.info "#{new_resource.path} already exists - nothing to do"
      else
        ::File.unlink(new_resource.path) if ::File.exists?(new_resource.path)
        if ::File.directory?(new_resource.source)
          converge_by "Ziping #{new_resource.source} to #{new_resource.path}" do
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

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  def do_acl_changes
    if access_controls.requires_changes?
      converge_by(access_controls.describe_changes) do
        access_controls.set_all
      end
    end
  end

  # Cache a file locally in `Chef::Config[:file_cache_path]`.
  # @note The file is gargbage collected at the end of a run.
  #
  # @param source [String, URI]
  #   source file path
  # @param checksum [String]
  #   the sha-1 checksum of the file
  #
  # @return [String]
  #   path to the cached file
  def cached_file(src, checksum = nil)
    if src =~ URI::ABS_URI && %w[ftp http https].include?(URI.parse(src).scheme)
      file = ::File.basename(URI.unescape(URI.parse(src).path))
      cache_file_path = ::File.join(Chef::Config[:file_cache_path], file)
      Chef::Log.info "Caching file #{src} at #{cache_file_path}"
      dl = Chef::Resource::Download.new(cache_file_path, run_context)
      dl.source src
      dl.checksum checksum if checksum
      dl.run_action(:create)
    else
      cache_file_path = src
    end

    cache_file_path
  end
end
