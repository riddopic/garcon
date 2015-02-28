# encoding: UTF-8
#
# Cookbook Name:: garcon
# Resource:: house_keeping
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

# House keeping service
#
class Chef::Resource::HouseKeeping < Chef::Resource
  include Garcon

  # The module where Chef should look for providers for this resource
  #
  # @param [Module] arg
  #   the module containing providers for this resource
  # @return [Module]
  #   the module containing providers for this resource
  # @api private
  provider_base Chef::Provider::HouseKeeping

  # The value of the identity attribute
  #
  # @return [String]
  #   the value of the identity attribute.
  # @api private
  identity_attr :path

  # Maps a short_name (and optionally a platform and version) to a
  # Chef::Resource
  #
  # @param [Symbol] arg
  #   short_name of the resource
  # @return [Chef::Resource::HouseKeeping]
  #   the class of the Chef::Resource based on the short name
  # @api private
  provides :house_keeping, os: 'linux'

  # Adds actions to the list of valid actions for this resource
  #
  # @return [Chef::Provider::HouseKeeping]
  # @api public
  actions :purge

  # Sets the default action
  #
  # @return [undefined]
  # @api private
  default_action :purge

  attribute :path,
            kind_of:        String,
            callbacks:    { path: ->(path) { validate_path(path, :dir) }},
            name_attribute: true

  attribute :exclude,
            kind_of: [String, Regexp],
            default: nil

  attribute :manage_symlink_source,
            kind_of: [TrueClass, FalseClass],
            default: true

  attribute :force_unlink,
            kind_of: [TrueClass, FalseClass],
            default: true

  attribute :age,
            kind_of: Integer,
            default: nil

  attribute :size,
            kind_of: String,
            regex:   /\d+[kmgt]{1}b{0,1}/i,
            default: nil

  attribute :directory_size,
            kind_of: String,
            regex:   /\d+[kmgtpe]{1}b{0,1}/i,
            default: nil

  attribute :recursive,
            kind_of: [TrueClass, FalseClass],
            default: false
end
