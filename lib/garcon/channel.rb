# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2012-2014 Stefano Harding
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

# A channel lets you send and receive various messages in a thread-safe way.
# It also allows for guards upon sending and retrieval, to ensure the passed
# messages are safe to be consumed.
#
class Thread::Channel
	include Garcon::Utils

	# Create a channel with optional initial messages and optional channel guard.
	def initialize(messages = [], &block)
		@messages = []
		@mutex    = Mutex.new
		@check    = block
		log.debug "Instance #{log_prefix} called"

		messages.each { |msg| send msg }
	end

	# Send a message to the channel.
	#
	# If there's a guard, the value is passed to it, if the guard returns a falsy
  # value an ArgumentError exception is raised and the message is not sent.
	def send(what)
		if @check && !@check.call(what)
			raise ArgumentError, 'guard mismatch'
		end

		@mutex.synchronize do
      @messages << what
      cond.broadcast if cond?
    end

		self
	end

	# Receive a message, if there are none the call blocks until there's one.
	#
	# If a block is passed, it's used as guard to match to a message.
	def receive(&block)
		message = nil
		found   = false

		if block
			until found
				@mutex.synchronize do
					if index = @messages.find_index(&block)
						message = @messages.delete_at(index)
						found   = true
					else
						cond.wait @mutex
					end
        end
			end
		else
			until found
				@mutex.synchronize do
					if @messages.empty?
						cond.wait @mutex
					end

					unless @messages.empty?
						message = @messages.shift
						found   = true
					end
        end
			end
		end

		message
	end

	# Receive a message, if there are none the call returns nil.
	#
	# If a block is passed, it's used as guard to match to a message.
	def receive!(&block)
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
