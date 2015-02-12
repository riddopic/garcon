# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: extenterator
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

module Garcon
  module Resource
    module Extenterator
      module ClassMethods
        # Mimic the LWRP DSL providing a `default_action` method
        #
        # @param [Symbol, String] name
        #   the default action
        # @return [undefined]
        # @api private
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
        # @return [undefined]
        # @api private
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
        # @api private
        def attribute(name, opts)
          define_method(name) do |arg=nil, &block|
            arg = block if arg.nil?
            set_or_return(name, arg, opts)
          end
        end

        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
        #
        # @api private
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods

      def initialize(*args)
        super
        # Try to not stomp on stuff if already set in a parent
        @action = self.class.default_action if @action == :nothing
        (@allowed_actions << self.class.actions).flatten!.uniq!
      end
    end

    module LazyAttrs
      module ClassMethods
        # Lazy loader for resources, allows for easy defaults from attributes
        #
        # @return [undefined]
        # @api private
        def lazy(&block)
          Chef::DelayedEvaluator.new(&block)
        end

        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
        #
        # @api private
        def included(klass)
          super
          klass.extend ClassMethods
        end
      end

      extend ClassMethods

      # Use `Chef::DelayedEvaluator` in rousources for easy defaults
      #
      # @return [undefined]
      # @api private
      def set_or_return(symbol, arg, validation)
        if validation && validation[:default].is_a?(Chef::DelayedEvaluator)
          validation = validation.dup
          validation[:default] = instance_eval(&validation[:default])
        end
        super(symbol, arg, validation)
      end
    end

    module HappyDefaults
      module ClassMethods

        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
        #
        # @api private
        def included(klass)
          super
          klass.extend ClassMethods
        end
      end

      extend ClassMethods

      # Invokes the public method whose name goes as first argument just like
      # `public_send` does, except that if the receiver does not respond to
      # it the call returns `nil` rather than raising an exception.
      #
      # @note `_?` is defined on `Object`. Therefore, it won't work with
      # instances of classes that do not have `Object` among their ancestors,
      # like direct subclasses of `BasicObject`.
      #
      # @param [String] object
      #   The object to send the method to.
      #
      # @param [Symbol] method
      #   The method to send to the object.
      #
      def _?(*args, &block)
        if args.empty? && block_given?
          yield self
        else
          resp = public_send(*args[0], &block) if respond_to?(args.first)
          return nil if resp.nil?
          !!resp == resp ? args[1] : "#{args[1]} #{resp}"
        end
      end

      # @return [String] object inspection
      def inspect
        instance_variables.inject([
          "\n#<#{self.class}:0x#{self.object_id.to_s(16)}>",
          "\tInstance variables:"
        ]) do |result, item|
          result << "\t\t#{item} = #{instance_variable_get(item)}"
          result
        end.join("\n")
      end

      # @return [String] string of instance
      def to_s
        "<#{self.class}:0x#{self.object_id.to_s(16)}>"
      end
    end

    # Set @resource_name automatically
    #
    # @return [undefined]
    # @api private
    def initialize(*args)
      super
      @resource_name ||= Chef::Mixin::ConvertToClassName.convert_to_snake_case(
        self.class.name, 'Chef::Resource'
      ).to_sym if self.class.name
    end
  end

  module Provider
    module Extenterator
      module ClassMethods
        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
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
