# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: provider_concurrent
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

class Chef::Provider::Concurrent < Chef::Provider::LWRPBase
  include Garcon::Helpers

  use_inline_resources if defined?(:use_inline_resources)

  # @return [Chef::Provider::ZipFile] Load and return the current resource.
  def load_current_resource
    @current_resource ||= Chef::Resource::Concurrent.new(new_resource.name)
  end

  # @return [TrueClass, FalseClass] WhyRun is supported by this provider.
  def whyrun_supported?
    true
  end

  action :run do
    converge_by "Concurrent #{new_resource.name} if you can..." do
      cached_new_resource = new_resource
      cached_current_resource = current_resource

      sub_run_context = @run_context.dup
      sub_run_context.resource_collection = Chef::ResourceCollection.new

      begin
        original_run_context, @run_context = @run_context, sub_run_context
        instance_eval(&@new_resource.block)
      ensure
        @run_context = original_run_context
      end

      begin
        Thread.process do
          Chef::Runner.new(sub_run_context).converge
        end
      ensure
        if sub_run_context.resource_collection.any?(&:updated?)
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  # def recipe_block_run(&block)
  #   @run_context.resource_collection = Chef::ResourceCollection.new
  #   instance_eval(&block)
  #   Chef::Runner.new(@run_context).converge
  # end
  #
  # def recipe_block(description, &block)
  #   recipe = self
  #   ruby_block "recipe_block[#{description}]" do
  #     block do
  #       recipe.instance_eval(&block)
  #     end
  #   end
  # end
  #
  # def recipe_fork(description, &block)
  #   block_body = proc do
  #     fork { recipe_block_run(&block) }
  #   end
  #   recipe_block(description, &block_body)
  # end
end

Chef::Platform.set(
  platform: :linux,
  resource: :concurrent,
  provider: Chef::Provider::Concurrent
)

require 'thread'

# A channel lets you send and receive various messages in a thread-safe way.
#
# It also allows for guards upon sending and retrieval, to ensure the passed
# messages are safe to be consumed.
class Thread::Channel
	# Create a channel with optional initial messages and optional channel guard.
	def initialize (messages = [], &block)
		@messages = []
		@mutex    = Mutex.new
		@check    = block

		messages.each {|o|
			send o
		}
	end

	# Send a message to the channel.
	#
	# If there's a guard, the value is passed to it, if the guard returns a falsy value
	# an ArgumentError exception is raised and the message is not sent.
	def send (what)
		if @check && !@check.call(what)
			raise ArgumentError, 'guard mismatch'
		end

		@mutex.synchronize {
			@messages << what

			cond.broadcast if cond?
		}

		self
	end

	# Receive a message, if there are none the call blocks until there's one.
	#
	# If a block is passed, it's used as guard to match to a message.
	def receive (&block)
		message = nil
		found   = false

		if block
			until found
				@mutex.synchronize {
					if index = @messages.find_index(&block)
						message = @messages.delete_at(index)
						found   = true
					else
						cond.wait @mutex
					end
				}
			end
		else
			until found
				@mutex.synchronize {
					if @messages.empty?
						cond.wait @mutex
					end

					unless @messages.empty?
						message = @messages.shift
						found   = true
					end
				}
			end
		end

		message
	end

	# Receive a message, if there are none the call returns nil.
	#
	# If a block is passed, it's used as guard to match to a message.
	def receive! (&block)
		if block
			@messages.delete_at(@messages.find_index(&block))
		else
			@messages.shift
		end
	end

	private
	def cond?
		instance_variable_defined? :@cond
	end

	def cond
		@cond ||= ConditionVariable.new
	end
end

class Thread
	# Helper to create a channel.
	def self.channel (*args, &block)
		Thread::Channel.new(*args, &block)
	end
end

class Thread::Process
	def self.all
		@@processes ||= {}
	end

	def self.register (name, process)
		all[name] = process
	end

	def self.unregister (name)
		all.delete(name)
	end

	def self.[] (name)
		all[name]
	end

	# Create a new process executing the block.
	def initialize (&block)
		@channel = Thread::Channel.new

		Thread.new {
			instance_eval(&block)

			@channel = nil
		}
	end

	# Send a message to the process.
	def send (what)
		unless @channel
			raise RuntimeError, 'the process has terminated'
		end

		@channel.send(what)

		self
	end

	alias << send

	private
	def receive
		@channel.receive
	end

	def receive!
		@channel.receive!
	end
end

class Thread
	# Helper to create a process.
	def self.process (&block)
		Thread::Process.new(&block)
	end
end
