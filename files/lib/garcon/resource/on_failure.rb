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

module OnFailDoThis
  def run_action_rescued(action = nil)
    run_action_unrescued(action)
    Chef::Log.debug "Finished running #{new_resource.resource_name}" \
                    "[#{new_resource.name}] -- so no exception"
  rescue Exception => e
    Chef::Log.info "#{new_resource.resource_name}[#{new_resource.name}] " \
                   "failed with: #{e.inspect}"
    if new_resource.instance_variable_defined?('@on_fail_handlers'.to_sym)
      new_resource.on_fail_handlers.each do |on_fail_struct|
        if on_fail_struct.options[:retries] > 0 &&
          (on_fail_struct.exceptions.any? { |klass|
            e.is_a?(klass) } || on_fail_struct.exceptions.empty?)
          on_fail_struct.options[:retries] -= 1

          Chef::Log.debug "Executing the block"
          instance_exec(new_resource, &on_fail_struct.block)

          Chef::Log.debug "Retrying the resource action"
          run_action_rescued(action)
          return
        end
      end
    end
    Chef::Log.debug "No on_fail handlers defined or finished retrying."
    raise e
  end

  def notify(action, notifying_resource)
    run_context.resource_collection.find(notifying_resource).run_action(action)
  end

  def self.included(base)
    base.class_eval do
      alias_method :run_action_unrescued, :run_action
      alias_method :run_action, :run_action_rescued
    end
  end

  unless Chef::Provider.ancestors.include?(OnFailDoThis)
    Chef::Provider.send(:include, OnFailDoThis)
  end
end

class Chef
  class Resource
    class OnFail < Struct.new(:options, :exceptions, :block); end

    attr_accessor :on_fail_handlers

    def on_fail(*args, &block)
      options    = { retries: 1 }
      exceptions = []
      args.each do |arg|
        exceptions  << arg  if arg.is_a?(Class)
        options.merge!(arg) if arg.is_a?(Hash)
      end
      @on_fail_handlers ||= []
      @on_fail_handlers << OnFail.new(options || {}, exceptions || [], block)
    end
  end
end
