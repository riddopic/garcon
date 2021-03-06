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

require_relative 'resource/blender'
require_relative 'resource/chef_helpers'
require_relative 'resource/jambalaya'
require_relative 'resource/log'
#require_relative 'resource/marzipan'
require_relative 'resource/node'
require_relative 'resource/patissier'
require_relative 'resource/secret_bag'
require_relative 'resource/validations'

module Garcon
  # Extend Resource with class and instance methods.
  #
  module Resource
    include Patissier
    include Validations
    include Garcon::Retry
    include Garcon::Timeout
    include Garcon::UrlHelper
    include Garcon::FileHelper
    include Garcon::ChefHelpers
    include Garcon::Interpolation

    module ClassMethods

      # Allow for chaining of resources together into a parent/child
      # relationship.
      #
      def resource_descendant(namespace = nil)
        include Garcon::Resource::ResourceDescendant
        base_namespace(namespace) unless namespace.nil?
      end

      def descendant(parent_type = nil, parent_optional = nil)
        include Garcon::Resource::Descendant
        parent_type(parent_type)         if parent_type
        parent_optional(parent_optional) if parent_optional
      end

      # Interpolate node attributes automatically.
      #
      def interpolate(namespace = nil)
        node.set[namespace] = interpolate(Garcon.config.stash[namespace])
      end

      # Combine a resource and provider class for quick and easy oven baked
      # goodness. Never has cooking been this fun since the invention of the
      # grocery store!
      #
      def blender
        include Garcon::Resource::Blender
      end

      # Hook called when module is included, extends a descendant with class
      # and instance methods.
      #
      # @param [Module] descendant
      #   the module or class including Odsee
      #
      # @return [self]
      #
      # @api private
      def included(descendant)
        super
        descendant.extend ClassMethods
      end
    end

    extend ClassMethods
  end

  # Extend Provider with class and instance methods.
  #
  module Provider
    include Patissier
    include Garcon::ChefHelpers
  end

  # Hook called when module is included, extends a descendant with class
  # and instance methods.
  #
  # @param [Module] descendant
  #   the module or class including Odsee
  #
  # @return [self]
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
end

# Callable form to allow passing in options:
#
def Garcon(opts = {})
  if opts.is_a?(Class)
    opts = { parent: opts }
  end

  mod = Module.new

  def mod.name
    super || 'Garcon'
  end

  mod.define_singleton_method(:included) do |base|
    super(base)
    base.class_exec { include Garcon }
    if base < Chef::Resource
      base.descendant(opts[:parent], opts[:optional]) if opts[:parent]
      base.resource_descendant(opts[:namespace])      if opts[:container]
      base.interpolate(opts[:node], opts[:namespace]) if opts[:interpolate]
      base.blender if opts[:blender]
    end
  end

  mod
end

unless Chef::Recipe.ancestors.include?(Garcon::ChefHelpers)
  Chef::Recipe.send(:include,   Garcon::ChefHelpers)
  Chef::Resource.send(:include, Garcon::ChefHelpers)
  Chef::Provider.send(:include, Garcon::ChefHelpers)
end

unless Chef::Recipe.ancestors.include?(Garcon::Interpolation)
  Chef::Recipe.send(:include,   Garcon::Interpolation)
  Chef::Resource.send(:include, Garcon::Interpolation)
  Chef::Provider.send(:include, Garcon::Interpolation)
end
