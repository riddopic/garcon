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

require 'find' unless defined?(Find)
require_relative 'garcon'

class Chef::Provider::ZipFile < Chef::Provider::LWRPBase
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

  action :unzip do
    safe_require('zip', constant: 'Zip')

    converge_by 'Unzipping file' do
      unzip(new_resource.source,
            new_resource.destination,
            new_resource.remove_after)
      apply_ownership(new_resource.destination)

      Chef::Log.info "#{new_resource.source} unzipped to " \
                     "#{new_resource.destination}"
      new_resource.updated_by_last_action(true)
    end
  end

  action :zip do
    fail NotImplementedError
  end

  protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

  def unzip(zip_file, destination, remove_after)
    Zip::File.open(zip_file) do |zip|
      zip.each do |entry|
        path = ::File.join(destination, entry.name)
        FileUtils.mkdir_p(::File.dirname(path))
        if ::File.exist?(path) && !::File.directory?(path)
          FileUtils.rm(path)
        end
        zip.extract(entry, path)
      end
    end

    FileUtils.rm(zip_file) if remove_after
  end

  def apply_ownership(dir)
    directory dir do
      owner new_resource.owner if new_resource.owner
      group new_resource.group if new_resource.group
      mode  new_resource.mode  if new_resource.mode
      recursive true
      action :create
    end
  end
end

