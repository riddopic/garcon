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

require 'chef/resource_collection'
require 'chef/runner'

module Garcon
  module RunNow
    module Mixin
      # Adds a `run_now` method onto Resources so you can immediately execute
      # the resource block. This is a shortcut so you do not have to set the
      # action to :nothing, and then use the `.run_action` method with the
      # desired action.
      #
      # @example
      #     service 'sshd' do
      #       action [:enable, :start]
      #     end.run_now
      #
      def run_now(resource = nil)
        resource ||= self
        actions = Array(resource.action)
        Chef::Log.debug "Immediate execution of #{resource.name} #{actions}"
        resource.action(:nothing)
        actions.each { |action| resource.run_action(action) }
      end
    end
  end

  class Jambalaya < Chef::ResourceCollection
    attr_accessor :parent

    def initialize(parent)
      @parent = parent
      super
    end

    def lookup(resource)
      super
    rescue Chef::Exceptions::ResourceNotFound
      @parent.lookup(resource)
    end

    def recursive_each(&block)
      if @parent
        if @parent.respond_to?(:recursive_each)
          @parent.recursive_each(&block)
        else
          @parent.each(&block)
        end
      end
      each(&block)
    end
  end

  class Tournant < Chef::Runner
    def initialize(resource, *args)
      super(*args)
      @resource = resource
    end

    def run_delayed_notifications(error = nil)
      return super if error
      delayed_actions.each do |notification|
        notifications = run_context.delayed_notifications(@resource)
        if run_context.delayed_notifications(@resource).any? { |exist_notify|
          exist_notify.duplicates?(notification)
        }
          Chef::Log.info "#{@resource} not queuing delayed action " \
                         "#{notification.action} on #{notification.resource} " \
                         "(delayed), as it's already been queued"
        else
          notifications << notification
        end
      end
    end
  end

  module Mashup

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def mashup_block(mashup_context = nil, &block)
      mashup_context ||= @run_context
      context_n_mash = mashup_context.dup
      context_n_mash.resource_collection =
        Jambalaya.new(mashup_context.resource_collection)

      begin
        outer_run_context = @run_context
        @run_context = context_n_mash
        instance_eval(&block)
      ensure
        @run_context = outer_run_context
      end

      context_n_mash
    end

    def global_resource_collection
      collection = @run_context.resource_collection
      while collection.respond_to?(:parent) && collection.parent
        collection = collection.parent
      end
      collection
    end
  end

  module Resource
    class SilentReCol < Chef::ResourceCollection
      def to_text
        "[#{all_resources.map(&:to_s).join(', ')}]"
      end
    end

    module ResourceDescendant
      include Mashup
      include Chef::DSL::Recipe

      attr_reader :descendant

      def initialize(*args)
        super
        @descendant = SilentReCol.new
      end

      def after_created
        super
        unless @descendant.empty?
          self_ = self
          order = Chef::Resource::RubyBlock.new('order', @run_context)
          order.block do
            collection = self_.run_context.resource_collection
            collection.all_resources.delete(self_)
            collection.all_resources[collection.iterator.position] = self_
            if by_name = collection.instance_variable_get(:@by_name)
              by_name[self_.to_s] = collection.iterator.position
            end
            collection.iterator.skip_back
          end
          @run_context.resource_collection.insert(order)
          @descendant.each { |r| @run_context.resource_collection.insert(r) }
        end
      end

      def method_missing(method_symbol, name=nil, &block)
        return super unless name
        self_ = self
        resource = []
        created_at = caller[0]
        mashup_block do
          namespace = if self.class.base_namespace == true
            self.name
          elsif self.class.base_namespace.is_a?(Proc)
            instance_eval(&self.class.base_namespace)
          else
            self.class.base_namespace
          end
          sub_name = if name && !name.empty?
                       namespace ? "#{namespace}::#{name}" : name
                     else
                       namespace || self.name
                     end
          resource << super(method_symbol, sub_name) do
            parent(self_) if respond_to?(:parent)
            self.source_line = created_at
            instance_exec(&block) if block
          end
        end
        register_descendant(resource.first) if resource.first
        resource.first
      end

      def register_descendant(resource)
        descendant.lookup(resource)
      rescue Chef::Exceptions::ResourceNotFound
        descendant.insert(resource)
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def to_ary
        nil
      end

      module ClassMethods
        def base_namespace(val = nil)
          @base_namespace = val unless val.nil?
          if @base_namespace.nil?
            if superclass.respond_to?(:base_namespace)
              superclass.base_namespace
            else
              true
            end
          else
            @base_namespace
          end
        end

        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods
    end

    module Descendant
      class Parent
        attr_accessor :resource

        def initialize(resource)
          @resource = resource
        end

        def to_text
          @resource.to_s
        end
      end

      module ClassMethods
        def ptype(type = nil)
          @ptype = type if type
          raise "Parent must be a class" unless type.is_a?(Class) && !type.nil?
          @ptype ||
            (superclass.respond_to?(:ptype) ? superclass.ptype : Chef::Resource)
        end

        def parent_optional(value = nil)
          unless value.nil?
            @parent_optional = value
          end
          if @parent_optional.nil?
            superclass.respond_to?(:ptype) ? superclass.ptype : false
          else
            @parent_optional
          end
        end

        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods

      def parent(arg = nil)
        if arg
          if arg.is_a?(String) && !arg.includes?('[')
            parent_klass = Garcon::Inflections.snakeify(
              self.class.ptype.name, 'Chef::Resource'
            )
            arg = "#{parent_klass}[#{arg}]"
          end
          if arg.is_a?(String) || arg.is_a?(Hash)
            arg = @run_context.resource_collection.find(arg)
          elsif !arg.is_a?(self.class.ptype)
            raise "Unknown parent resource: #{arg}"
          end
          @parent = Parent.new(arg)
        elsif !@parent
          @run_context.resource_collection.each do |r|
            @parent = Parent.new(r) if r.is_a?(self.class.ptype)
          end
          unless @parent || self.class.parent_optional
            raise "No parent found for #{self}"
          end
        end
        @parent && @parent.resource
      end

      def after_created
        super
        parent.register_descendant(self) if parent
      end
    end
  end
end
