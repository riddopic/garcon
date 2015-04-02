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

require 'thread'
require_relative 'condition'

module Garcon

  # When an `Event` is created it is in the `unset` state. Threads can choose to
  # `#wait` on the event, blocking until released by another thread. When one
  # thread wants to alert all blocking threads it calls the `#set` method which
  # will then wake up all listeners. Once an `Event` has been set it remains
  # set. New threads calling `#wait` will return immediately. An `Event` may be
  # `#reset` at any time once it has been set.
  #
  class Event

    # Creates a new `Event` in the unset state. Threads calling `#wait` on the
    # `Event` will block.
    #
    def initialize
      @set       = false
      @mutex     = Mutex.new
      @condition = Condition.new
    end

    # Is the object in the set state?
    #
    # @return [Boolean]
    #   indicating whether or not the `Event` has been set
    def set?
      @mutex.lock
      @set
    ensure
      @mutex.unlock
    end

    # Trigger the event, setting the state to `set` and releasing all threads
    # waiting on the event. Has no effect if the `Event` has already been set.
    #
    # @return [Boolean]
    #   should always return `true`
    def set
      @mutex.lock
      unless @set
        @set = true
        @condition.broadcast
      end
      true
    ensure
      @mutex.unlock
    end

    def try?
      @mutex.lock

      if @set
        false
      else
        @set = true
        @condition.broadcast
        true
      end

    ensure
      @mutex.unlock
    end

    # Reset a previously set event back to the `unset` state.
    # Has no effect if the `Event` has not yet been set.
    #
    # @return [Boolean]
    #   should always return `true`
    def reset
      @mutex.lock
      @set = false
      true
    ensure
      @mutex.unlock
    end

    # Wait a given number of seconds for the `Event` to be set by another
    # thread. Will wait forever when no `timeout` value is given. Returns
    # immediately if the `Event` has already been set.
    #
    # @return [Boolean]
    #   true if the `Event` was set before timeout else false
    def wait(timeout = nil)
      @mutex.lock

      unless @set
        remaining = Condition::Result.new(timeout)
        while !@set && remaining.can_wait?
          remaining = @condition.wait(@mutex, remaining.remaining_time)
        end
      end

      @set
    ensure
      @mutex.unlock
    end
  end
end