# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: provider_concurrent
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

require_relative 'pool'

class Chef::Provider::Concurrent < Chef::Provider
  include Garcon

  provides :concurrent, os: 'linux'

  def initialize(new_resource, run_context)
    super(new_resource, run_context)
  end

  # Boolean indicating if WhyRun is supported by this provider.
  #
  # @return [TrueClass, FalseClass]
  #
  # @api private
  def whyrun_supported?
    true
  end

  # Load and return the current resource.
  #
  # @return [Chef::Provider::Dsccsetup]
  #
  # @api private
  def load_current_resource
    @current_resource = Chef::Resource::Concurrent.new(new_resource.name)
  end

  def action_start
    begin
      Chef::Log.info 'Thread-pool already running - nothing to do' if @@pool
    rescue
      converge_by 'Concurrent thread-pool starting up.' do
        @@pool ||= Thread.pool(new_resource.min, new_resource.max)
        pool_handler
        Chef::Log.info "Thread-pool #{@@pool} startup complete."
      end
    end
  end

	# Shut down the pool, it will block until all tasks have finished running.
  #
  def action_stop
    if @@pool.shutdown?
      Chef::Log.info "#{new_resource} already shutdown - nothing to do."
    else
      converge_by "Concurrent pool #{new_resource} is being shutdown" do
        @@pool.shutdown
        Chef::Log.info "Pool #{new_resource} shutdown complete."
      end
    end
  end

  def action_run
    @@pool.process do
      job = job_num
      converge_by "#{job}: Concurrent converge for #{new_resource.name}" do
        begin
          saved_run_context = @run_context
          temp_run_context = @run_context.dup
          @run_context = temp_run_context
          @run_context.resource_collection = Chef::ResourceCollection.new

          return_value = instance_eval(&@new_resource.block)
          Chef::Runner.new(@run_context).converge
          return_value
        ensure
          @run_context = saved_run_context
          if temp_run_context.resource_collection.any? {|r| r.updated? }
            new_resource.updated_by_last_action(true)
          end
        end
      end
      Chef::Log.info "#{job}: Completed converge for #{new_resource.name}"
    end
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  def job_num
    @@job ||= 0
    @@job += 1
  end

  def pool_handler
    handler = ::File.join(node[:chef_handler][:handler_path], 'threadpool.rb')

    cookbook_file handler do
      owner 'root'
      group 'root'
      mode 00755
      action :create
    end

    chef_handler 'ThreadPool' do
      source handler
      arguments @@pool
      supports :report => true, :exception => true
      action :enable
    end
  end
end
