# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2012-2014 Stefano Harding
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

require 'garcon/configuration'

module Garcon

  # Raised when errors occur during configuration.
  ConfigurationError = Class.new(StandardError)

  # Raised when an object's methods are called when it has not been
  # properly initialized.
  InitializationError = Class.new(StandardError)

  # Raised when an operation times out.
  TimeoutError = Class.new(StandardError)

  class << self
    # @param [TrueClass, FalseClass] sets the global logging configuration.
    # @return [Garcon]
    # @api public
    def logging=(value)
      configuration.logging = value
      self
    end

    # @return [TrueClass, FalseClass] the global logging setting.
    # @api public
    def logging
      configuration.logging
    end

    # Provides access to the global configuration.
    #
    # @example
    #   Garcon.config do |config|
    #     config.logging = true
    #   end
    #
    # @return [Configuration]
    #
    # @api public
    def config(&block)
      yield configuration if block_given?
      configuration
    end

    # @return [Configuration] global configuration instance.
    # @api private
    def configuration
      @configuration ||= Configuration.new
    end
  end
end

require 'garcon/logging'
require 'garcon/utils'
require 'garcon/condition'
require 'garcon/timeout'
require 'garcon/event'
require 'garcon/lock'
require 'garcon/version'
