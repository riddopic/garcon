# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014 Stefano Harding
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

require 'uri'  unless defined?(URI)
require_relative 'garcon'

class Chef::Provider::Download < Chef::Provider::LWRPBase
  include Chef::Mixin::ShellOut
  include Garcon

  use_inline_resources if defined?(:use_inline_resources)

  # WhyRun is supported by this provider
  #
  # @return [TrueClass, FalseClass]
  #
  def whyrun_supported?
    true
  end

  # Load and return the current resource
  #
  # @return [Chef::Resource::WebsphereResource]
  #
  def load_current_resource
  end

  action :run do
    cmd = 'aria2c '
    cmd << "-d #{new_resource.destination} "
    cmd << "-s #{new_resource.connections} "
    cmd << "-x #{new_resource.max_connections} "
    unless new_resource.checksum.nil?
      cmd << "--checksum=sha-1=#{new_resource.checksum} "
    end
    cmd << new_resource.source

    converge_by 'Downloading file' do
      Chef::Log.info shell_out!(cmd).stdout
      apply_owner(::File.basename(URI.parse(new_resource.source).path))
    end
  end

  protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

  def apply_owner(file)
    f = Chef::Resource::File.new(file, run_context)
    f.owner new_resource.owner if new_resource.owner
    f.group new_resource.group if new_resource.group
    f.mode  new_resource.mode  if new_resource.mode
    f.run_action :touch
  end
end
