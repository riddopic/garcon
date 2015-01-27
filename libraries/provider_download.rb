# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: provider_download
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

class Chef::Provider::Download < Chef::Provider::LWRPBase
  include Chef::Mixin::EnforceOwnershipAndPermissions
  include Chef::Mixin::Checksum
  include Chef::Mixin::ShellOut
  include Garcon::Helpers

  def initialize(name, run_context = nil)
    super
    do_prerequisite unless installed?('aria2c')
  end

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
    @current_resource ||= Chef::Resource::Download.new(new_resource.name)
    @current_resource.path(new_resource.path)
    if (@current_resource.exists = ::File.exist?(@current_resource.path))
      Chef::Log.debug "#{new_resource} checksumming file at #{new_resource.path}"
      @current_resource.checksum(checksum(@current_resource.path))
    else
      @current_resource.checksum(nil)
    end
    @current_resource
  end

  action :create do
    if !@current_resource.exists?
      converge_by "Downloading #{new_resource.path}" do
        do_download
        Chef::Log.info "#{new_resource} downloaded #{new_resource.path}"
      end
      new_resource.updated_by_last_action(true)
    elsif access_controls.requires_changes?
      converge_by(access_controls.describe_changes) do
        access_controls.set_all
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} already exists - nothing to do"
    end
  end

  action :create_if_missing do
    unless @current_resource.exists?
      converge_by "Downloading #{new_resource.path}" do
        do_download
        Chef::Log.info "#{new_resource} downloaded #{new_resource.path}"
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} already exists - nothing to do"
    end
  end

  action :delete do
    if @current_resource.exists?
      converge_by "Deleting file #{new_resource.path}" do
        do_backup unless ::File.symlink?(@new_resource.path)
        ::File.delete(new_resource.path)
        Chef::Log.info "#{new_resource} deleted file at #{new_resource.path}"
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} does not exists - nothing to do"
    end
  end

  action :touch do
    if @current_resource.exists?
      converge_by "Update utime on file #{new_resource.path}" do
        time = Time.now
        ::File.utime(time, time, new_resource.path)
        Chef::Log.info "#{new_resource.path} updated atime and mtime to #{time}"
      end
      new_resource.updated_by_last_action(true)
    else
      Chef::Log.info "#{new_resource.path} does not exists - nothing to do"
    end
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  def do_prerequisite
    concurrent(:pool) { block { prerequisite { |blk| self.send(:blk) } } }
  end

  def do_acl_changes
    if access_controls.requires_changes?
      converge_by(access_controls.describe_changes) do
        access_controls.set_all
      end
    end
  end

  def do_download
    cmd = 'aria2c '
    cmd << "-o #{new_resource.path} "
    cmd << "-s #{new_resource.connections} "
    cmd << "-x #{new_resource.max_connections} "
    unless new_resource.checksum.nil?
      cmd << "--checksum=sha-256=#{new_resource.checksum} "
    end
    cmd << new_resource.source
    Chef::Log.info shell_out!(cmd).stdout
    do_acl_changes
  end

  def do_backup(file = nil)
    Chef::Util::Backup.new(new_resource, file).backup!
  end
end
