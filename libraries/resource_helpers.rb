# encoding: UTF-8
#
# Cookbook Name:: garcon
# Resources:: resource_helpers
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

require 'chef/mash'
require 'chef/mixin/params_validate'

module Garcon
  class Busser < ::Mash
    include Chef::Mixin::ParamsValidate

    def method_missing(method, *args, &block)
      if (match = method.to_s.match(/(.*)=$/)) && args.size == 1
        self[match[1]] = args.first
      elsif (match = method.to_s.match(/(.*)\?$/)) && args.size == 0
        key?(match[1])
      elsif key?(method)
        self[method]
      else
        super
      end
    end

    def validate(map)
      data = super(symbolize_keys, map)
      data.each { |key, value| self[key.to_sym] = value }
    end

    def self.from_hash(hash)
      mash = Garcon::Busser.new(hash)
      mash.default = hash.default
      mash
    end
  end

  module Resource
    # Mixin to combine resource and providers so they can be implemented in the
    # same class.
    #
    module Synthesize
      # Coerce is_a? so that the DSL will consider this a Provider for the
      # purposes of attaching enclosing_provider.
      #
      def is_a?(klass)
        if klass == Chef::Provider
          true
        else
          super
        end
      end

      # Coerce provider_for_action so that the resource is also the provider.
      #
      def provider_for_action(action)
        provider(self.class.synthesize_provider_class) unless provider
        super
      end

      module ClassMethods
        # Define a provider action. The block should contain the usual provider
        # code.
        #
        def action(name, &block)
          synthesize_actions[name.to_sym] = block
          actions(name.to_sym) if respond_to?(:actions)
        end

        def synthesize_actions
          (@synthesize_actions ||= {})
        end

        # Create a provider class for the synthesize actions in this resource.
        # Inherits from the synthesize provider class of the resource's
        # superclass if present.
        #
        def synthesize_provider_class
          @synthesize_provider_class ||= begin
            provider_superclass = begin
              self.superclass.synthesize_provider_class
            rescue NoMethodError
              Chef::Provider
            end
            actions    = synthesize_actions
            class_name = self.name
            Class.new(provider_superclass) do
              include Garcon
              define_singleton_method(:name) { class_name + ' (synthesize)' }
              actions.each do |action, block|
                define_method(:"action_#{action}", &block)
              end
            end
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
    end
  end

  module ResourceHelper
    def attribute_mash(source = nil)
      source ||= self
      hash     = Hash.new
      pattern  = Regexp.new('^_set_or_return_(.+)$')
      source.public_methods(false).each do |method|
        pattern.match(method) do |meth|
          attribute = meth[1].to_sym
          hash[attribute] = send(attribute)
        end
      end
      Garcon::Busser.from_hash(hash)
    end

    def attribute_mash_formatted(default_data = nil, source = nil)
      source ||= self
      if default_data && (default_data.is_a?(Hash) || default_data.is_a?(Mash))
        data = default_data
      else
        data = Hash.new
      end
      data = Mash.from_hash(data) unless data.is_a?(Mash)
      data.merge!(attribute_mash(source))
      data = data.symbolize_keys
      max_iterations = 3
      data.each do |key, value|
        next unless value.is_a? String
        for i in 1..max_iterations
          other = value % data
          if (other == value)
            break
          else
            data[key] = value = other
          end
        end
      end
      Garcon::Busser.from_hash(data)
    end
  end
end
