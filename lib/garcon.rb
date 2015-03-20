# encoding: UTF-8
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

require 'ostruct'
require_relative 'garcon/version'
require_relative 'garcon/core_ext/blank'
require_relative 'garcon/core_ext/enumerable'
require_relative 'garcon/core_ext/hash'
require_relative 'garcon/core_ext/kernel'
require_relative 'garcon/core_ext/lazy'
require_relative 'garcon/core_ext/object'
require_relative 'garcon/core_ext/pathname'
require_relative 'garcon/core_ext/random'
require_relative 'garcon/core_ext/string'
require_relative 'garcon/core_ext/time'
require_relative 'garcon/inflections'
require_relative 'garcon/msg_from_god'
# require_relative 'garcon/configuration'
# require_relative 'garcon/exceptions'

# Base module which adds hooks to extend with class and instance methods.
#
module Garcon

  # Extends base class or a module with garcon methods
  #
  # @param [Object] object
  #
  # @return [undefined]
  #
  # @deprecated
  #
  # @api private
  def self.included(object)
    super
    if Class === object
      object.send(:include, ClassInclusions)
    else
      object.extend(ModuleExtensions)
    end
  end
  private_class_method :included

  # Extends an object with garcon extensions
  #
  # @param [Object] object
  #
  # @return [undefined]
  #
  # @api private
  def self.extended(object)
    object.extend(Extensions)
  end
  private_class_method :extended

  # Sets the global blender configuration
  #
  # @example
  #   Garcon.blender do |config|
  #     config.blender = true
  #   end
  #
  # @return [Garcon::Blender]
  #
  # @api public
  def self.blender(&block)
    configuration.blender(&block)
  end

  # Sets the global blender configuration value
  #
  # @param [Boolean] value
  #
  # @return [Garcon]
  #
  # @api public
  def self.blender=(value)
    configuration.blender = value
    self
  end

  # Returns the global blender setting
  #
  # @return [Boolean]
  #
  # @api public
  def self.blender
    configuration.blender
  end

  # Provides access to the global Garcon configuration
  #
  # @example
  #   Garcon.config do |config|
  #     config.blender = false
  #   end
  #
  # @return [Configuration]
  #
  # @api public
  def self.config(&block)
    yield configuration if block_given?
    configuration
  end

  # Global configuration instance
  #
  # @return [Configuration]
  #
  # @api private
  def self.configuration
    @configuration ||= Configuration.new
  end

  # @api private
  def self.warn(msg)
    Kernel.warn(msg)
  end
end

# require 'garcon/lazy_eval'
# require 'garcon/option_collector'
# require 'garcon/resource_name'
# require 'garcon/marzipan'
# require 'garcon/blender'
# require 'garcon/chef_node'
# require 'garcon/log'
# require 'garcon/secret_bag'
# require 'garcon/secrets'
# require 'garcon/panforte'
# require 'garcon/validations'
# require 'garcon/class_inclusions'
