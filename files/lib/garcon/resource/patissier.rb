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

require 'chef/dsl/recipe'
require_relative 'jambalaya'

# Provide DSL sweetness with syntactical sugar.
#
module Garcon
  module Resource
    # Our favorite Pâtissier adds DSL sweetness syntactical sugar on top of
    # Chef::Resource, so attributes, default action, etc. can be defined with a
    # more pleasing syntax.
    #
    module Patissier
      module ClassMethods

        # Maps a resource/provider (and optionally a platform and version) to a
        # Chef resource/provider. This allows finer grained per platform
        # resource attributes and the end of overloaded resource definitions.
        #
        # @note
        #   The provides method must be defined in both the custom resource and
        #   custom provider files and both files must have identical provides
        #   statement(s).
        #
        # @param [Symbol] name
        #   Name of a Chef resource/provider to map to.
        #
        # @return [undefined]
        def provides(name, opts = {})
          @provides_name = name
          super if defined?(super)
        end

        # Return the Symbolized name of the current resource/provider.
        #
        # @return [Symbol] resource_name
        def resource_name
          @provides_name || if name
            Garcon::Inflections.snakeify(name, 'Chef::Resource').to_sym
          end
        end

        # Mimic the LWRP DSL providing a `default_action` method
        #
        # @param [Symbol, String] name
        #   the default action
        #
        # @return [undefined]
        def default_action(name = nil)
          if name
            @default_action = name
            actions(name)
          end
          @default_action || (superclass.respond_to?(:default_action) &&
                              superclass.default_action) ||
                              :actions.first || :nothing
        end

        # Mimic the LWRP DSL providing a `action` method
        #
        # @param [Array<String, Symbol>] name
        #   the default action
        #
        # @return [undefined]
        def actions(*names)
          @actions ||= superclass.respond_to?(:actions) ?
                       superclass.actions.dup : []
          (@actions << names).flatten!.uniq!
          @actions
        end

        # Mimic the LWRP DSL providing a `attribute` method
        #
        # @param [Symbol] name
        # @param [Hash] opts
        #
        # @return [undefined]
        def attribute(name, opts)
          define_method(name) do |arg = nil, &block|
            arg = block if arg.nil?
            set_or_return(name, arg, opts)
          end
        end

        # Lazy loader for resources, allows for easy defaults from attributes
        #
        # @return [undefined]
        #
        # @api private
        def lazy(&block)
          Chef::DelayedEvaluator.new(&block)
        end

        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   the module or class including Garcon::Resource::Patissier
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

      # Constructor for Chef::Resource::YourResource
      #
      def initialize(*args)
        super
        @resource_name   ||= self.class.resource_name
        @action            = self.class.default_action if @action == :nothing
        (@allowed_actions << self.class.actions).flatten!.uniq!
      end

      # Use `Chef::DelayedEvaluator` in rousources for easy defaults
      #
      # @return [undefined]
      #
      # @api private
      def set_or_return(symbol, arg, validation)
        if validation && validation[:default].is_a?(Chef::DelayedEvaluator)
          validation = validation.dup
          validation[:default] = instance_eval(&validation[:default])
        end
        super(symbol, arg, validation)
      end
    end
  end

  # Chef::Provider::LWRPBase Base class from which LWRP providers inherit.
  #
  module Provider
    # Our favorite Pâtissier is at it again, adding syntactical sweetness and
    # sugar coating providers to please even the most discerning palate.
    #
    module Patissier
      include Mashup

      # Allows for including one (or more) recipes located in external cookbooks
      # as in the recipe DSL.
      #
      # @param [String, Proc] recipes
      #   The name of the recipes to include.
      #
      # @return [undefined]
      def include_recipe(*recipes)
        loaded_recipes = []
        mashup = mashup_block do
          recipes.each do |recipe|
            case recipe
            when String
              Chef::Log.debug "Loading recipe #{recipe} via include_recipe"
              loaded_recipes += run_context.include_recipe(recipe)
            when Proc
              r = Chef::Recipe.new(cookbook, new_resource.recipe, run_context)
              r.instance_eval(&r)
              loaded_recipes << r
            end
          end
        end

        Garcon::Tournant.new(new_resource, mashup).converge
        collection = global_resource_collection
        mashup.resource_collection.each do |r|
          collection.insert(r)
          collection.iterator.skip_forward if collection.iterator
        end
        loaded_recipes
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # Mark the resource as updated-by-last-action if any descendant resources
      # were updated.
      #
      def notifying_block(&block)
        begin
          mashup = mashup_block(&block)
          Garcon::Tournant.new(new_resource, mashup).converge
        ensure
          new_resource.updated_by_last_action(
            mashup && mashup.resource_collection.any?(&:updated?)
          )
        end
      end

      module ClassMethods
        # Hook called when module is included, extends a descendant with class
        # and instance methods.
        #
        # @param [Module] descendant
        #   the module or class including Garcon::Provider::Patissier
        #
        # @return [self]
        #
        # @api private
        def included(descendant)
          super
          descendant.extend ClassMethods
          if descendant.is_a?(Class) && descendant.superclass == Chef::Provider
            descendant.class_exec { include Implementation }
          end
          descendant.class_exec { include Chef::DSL::Recipe }
        end
      end

      module Implementation
        def load_current_resource
        end
      end

      extend ClassMethods
    end
  end
end
