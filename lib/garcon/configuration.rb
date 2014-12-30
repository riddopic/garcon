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

module Garcon

  # A Configuration instance
  class Configuration

    # Access the logging setting for this instance
    attr_accessor :logging

    # Access to the logging level for this instance
    attr_accessor :level

    # Initialized a configuration instance
    #
    # @return [undefined]
    #
    # @api private
    def initialize(options={})
      @logging = options.fetch(:logging, false)
      @level   = options.fetch(:level,   :info)

      yield self if block_given?
    end

    # @api private
    def to_h
      { logging: logging,
        level:   level
      }.freeze
    end
  end
end
