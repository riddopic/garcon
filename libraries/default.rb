# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: default
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

require_relative 'extenterator'
require_relative 'cli_helpers'

module Garcon
  # Include hooks to extend Resource with class and instance methods.
  #
  module Resource
    include LazyAttrs
    include HappyDefaults
    include Extenterator
    include CliHelpers
  end

  module Provider
    include Extenterator
  end

  # Extends a descendant with class and instance methods
  #
  # @param [Class] descendant
  #
  # @return [undefined]
  #
  # @api private
  def self.included(descendant)
    super
    if descendant < Chef::Resource
      descendant.class_exec { include Garcon::Resource }
    elsif descendant < Chef::Provider
      descendant.class_exec { include Garcon::Provider }
    end
  end
  private_class_method :included
end
