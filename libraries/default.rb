# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: default
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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

  # Include hooks to extend Resource with class and instance methods.
  #
  module Resource

    # Helper module to automatically set @resource_name
    #
    def initialize(*args)
      super
      @resource_name ||= Chef::Mixin::ConvertToClassName.convert_to_snake_case(
        self.class.name, 'Chef::Resource').to_sym
    end

    # Invokes the public method whose name goes as first argument just like
    # `public_send` does, except that if the receiver does not respond to it the
    # call returns `nil` rather than raising an exception.
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

    module ClassMethods
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
      def self.included(descendant)
        super
        descendant.extend(ClassMethods)
      end
      private_class_method :included
    end

    extend ClassMethods

    def set_or_return(symbol, arg, validation)
      if validation && validation[:default].is_a?(Chef::DelayedEvaluator)
        validation = validation.dup
        validation[:default] = instance_eval(&validation[:default])
      end
      super(symbol, arg, validation)
    end
  end

  module Provider
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
      descendant.class_exec { include Hoodie::Inflections }

    elsif descendant < Chef::Provider
      descendant.class_exec { include Garcon::Provider }
    end
  end
  private_class_method :included
end
