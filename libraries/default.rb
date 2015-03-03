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

require_relative 'validations'
require_relative 'zen_master'
require_relative 'exceptions'
require_relative 'resource_helpers'

# Include hooks to extend with class and instance methods.
#
module Garcon
  # Include hooks to extend Resource with class and instance methods.
  #
  module Resource
    include Validations
    include ZenMaster

    def self.included(descendant)
      super

      def descendant.synthesize
        include Garcon::Resource::Synthesize
      end
    end
  end

  # Include hooks to extend Provider with class and instance methods.
  #
  module Provider
    include ZenMaster
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
    descendant.class_exec { include Garcon::Exceptions }
    if descendant < Chef::Resource
      descendant.class_exec { include Garcon::Resource }
    elsif descendant < Chef::Provider
      descendant.class_exec { include Garcon::Provider }
    end
  end
  private_class_method :included
end

# Callable form to allow passing in options:
#   include Garcon(synthesize: true)
#
def Garcon(options = {})
  if options.is_a?(Class)
    options = { parent: options }
  end

  anonymous_module = Module.new

  def anonymous_module.name
    super || 'Garcon'
  end

  anonymous_module.define_singleton_method(:included) do |klass|
    super(klass)
    klass.class_exec { include Garcon }
    if klass < Chef::Resource
      klass.synthesize if options[:synthesize]
    end
  end

  anonymous_module
end
