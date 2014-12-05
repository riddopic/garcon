# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014 Stefano Harding
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

=begin
#<
The observer pattern is a software design pattern in which an object, called
the subject, maintains a list of its dependents, called observers, and notifies
them automatically of any state changes, usually by calling one of their
methods. It is mainly used to implement distributed event handling systems.

@section Examples

    # An example coming soon to a theater near you
    observable_event(:watcher) do
      ruby_block  do
      end
    end
#>
=end

module Observable
  def self.event(key, args = {}, &block)
    args = Mash.new(args)
    @event ||= Mash.new
    @event[key] ||= Mash.new
    if args[:recipes]
      @event[key][:recipes] = (@event[key][:recipes] + args[:recipes]).uniq
    end
    if args[:paths]
      @event[key][:paths] = (@event[key][:paths] + args[:paths]).uniq
    end
    if block_given?
      @event[key][:blocks] ||= []
      @event[key][:blocks] << block
    end
    true
  end

  def self.for(key, type)
    if @event && @event[key] && @event[key][type]
      @event[key][type]
    else
      []
    end
  end
end

module Observers
  def self.included(base)
    base.class_eval do
      include GenericNotifications

      base.send(:include, GenericNotifications)
      base.send(:include, RecipeNotifications)   if base == Chef::Recipe
      base.send(:include, ProviderNotifications) if base == Chef::Provider
    end
  end
  private_class_method :included

  module GenericNotifications
    def observable_event(*args, &block)
      Observable.event(*args, &block)
    end

    def notifications
      [:recipes, :paths, :blocks]
    end

    def notify_observers(key, notify_order = notifications)
      Chef::Log.info "Notify observers for: #{key}"
      notify_order.each do |type|
        Observable.for(key, type).each do |item|
          case type
          when :recipes
            parts = item.split('::')
            parts << 'default' unless parts.size > 1
            notify_recipe(*parts)
          when :paths
            notify_file(item)
          when :blocks
            notify_block(item)
          else
            raise ArgumentError, "#{type} is not a valid notification method"
          end
        end
      end
      Chef::Log.debug "Observer notification complete"
      true
    end

    def notify_recipe(cookbook, recipe)
      cb = Chef::CookbookLoader.new(Chef::Config[:cookbook_path])
      raise "'#{cookbook}' not found" unless cb.load_cookbooks[cookbook]
      rcp_path = cb.recipe_filenames_by_name[recipe]
      Chef::Log.info "Notify recipe: #{cookbook}::#{recipe}"
      notify_file(rcp_path, :no_log)
    end
  end

  module RecipeNotifications
    def notify_file(path, *args)
      Chef::Log.info "Notify file: #{path}" unless args.include?(:no_log)
      raise "file '#{path}' not found" unless ::File.exists?(path)
      from_file(path)
    end

    def notify_block(block)
      Chef::Log.debug 'Custom block notification'
      instance_eval(&block)
    end
  end

  module ProviderNotifications
    def notify_file(path, *args)
      Chef::Log.info "Notify file: #{path}" unless args.include?(:no_log)
      raise "file '#{path}' not found" unless ::File.exists?(path)
      recipe_eval { self.instance_eval(IO.read(path), path, 1) }
    end

    def notify_block(block)
      Chef::Log.debug 'Custom block notification'
      recipe_eval(&block)
    end
  end
end

Chef::Recipe.send(:include, Observers)
Chef::Resource.send(:include, Observers)
Chef::Provider.send(:include, Observers)
Chef::Provider::RubyBlock.send(:include, Observers)
