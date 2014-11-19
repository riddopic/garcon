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

require 'chef/provider/lwrp_base' unless defined?(Chef::Provider::LWRPBase)
require_relative 'thread_pool' unless defined?(ThreadPool)

class Chef::Provider::Thread < Chef::Provider::LWRPBase
  use_inline_resources if defined?(:use_inline_resources)

  def whyrun_supported?
    true
  end

  def load_current_resource
    true
  end

  include ThreadPool

  action :run do
    converge_by "executing thread #{@new_resource.name}" do
      _cached_new_resource = new_resource
      _cached_current_resource = current_resource

      sub_run_context = @run_context.dup
      sub_run_context.resource_collection = Chef::ResourceCollection.new

      begin
        original_run_context, @run_context = @run_context, sub_run_context
        instance_eval(&@new_resource.block)
      ensure
        @run_context = original_run_context
      end

      begin
        self.class.pool.post { Chef::Runner.new(sub_run_context).converge }
      ensure
        if sub_run_context.resource_collection.any?(&:updated?)
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  # Create a new thread pool.
  #
  def self.pool
    @@pool ||= ThreadPoolExecutor.new(
      min_threads:     8,
      max_threads:     120,
      idletime:        2 * 60,
      max_queue:       0,
      overflow_policy: :abort)
  end
end
