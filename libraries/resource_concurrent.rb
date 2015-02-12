# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: resource_concurrent
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

class Chef::Resource::Concurrent < Chef::Resource
  include Garcon

  # The module where Chef should look for providers for this resource
  #
  # @param [Module] arg
  #   the module containing providers for this resource
  # @return [Module]
  #   the module containing providers for this resource
  # @api private
  provider_base Chef::Provider::Download

  # The value of the identity attribute
  #
  # @return [String]
  #   the value of the identity attribute.
  # @api private
  identity_attr :name

  # Maps a short_name (and optionally a platform and version) to a
  # Chef::Resource
  #
  # @param [Symbol] arg
  #   short_name of the resource
  # @return [Chef::Resource::Concurrent]
  #   the class of the Chef::Resource based on the short name
  # @api private
  provides :concurrent, os: 'linux'

  # Set or return the list of `state attributes` implemented by the Resource,
  # these are attributes that describe the desired state of the system
  #
  # @return [Chef::Resource::Concurrent]
  # @api private
  state_attrs :state

  # Adds actions to the list of valid actions for this resource
  #
  # @return [Chef::Resource::Concurrent]
  # @api public
  actions :start, :shutdown, :run, :join

  # Sets the default action
  #
  # @return [undefined]
  # @api private
  default_action :run

  # @!attribute [w] exists
  #   @return [TrueClass, FalseClass] boolean, `true` if the resource exists
  attr_writer :exists

  def initialize(name, run_context=nil)
    super
    @name = name
    @resource_name = :concurrent
  end

  # The full path to the file, including the file name and its extension,
  # default value: the name of the resource block
  #
  # @param [String] path
  # @return [String]
  # @api public
  attribute :path,
            kind_of: [Symbol, String],
            name_attribute: true

  attribute :lock,
            kind_of: Class,
            default: Monitor.new

  attribute :min,
            kind_of: Integer,
            default: 4

  attribute :max,
            kind_of: Integer,
            default: nil

  attribute :block,
            kind_of: Proc

  def block(&block)
    if block_given? && block
      @block = block
    else
      @block
    end
  end
end
