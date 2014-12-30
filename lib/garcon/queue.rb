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

require 'thread'

module Garcon
  class BoundedQueue
    def initialize(max_size = :infinite)
      @lock  = Mutex.new
      @items = []
      @item_available = ConditionVariable.new
      @max_size = max_size
      @space_available = ConditionVariable.new
    end

    def push(obj, timeout=:never, &timeout_policy)
      timeout_policy ||= -> do
        raise "Push timed out"
      end
      wait_for_condition(
        @space_available,
        ->{!full?},
        timeout,
        timeout_policy) do

        @items.push(obj)
        @item_available.signal
      end
    end

    def pop(timeout = :never, &timeout_policy)
      timeout_policy ||= ->{nil}
      wait_for_condition(
        @item_available,
        ->{@items.any?},
        timeout,
        timeout_policy) do

        @items.shift
      end
    end

    private

    def full?
      return false if @max_size == :infinite
      @max_size <= @items.size
    end

    def wait_for_condition(
        cv, condition_predicate, timeout=:never, timeout_policy=->{nil})
      deadline = timeout == :never ? :never : Time.now + timeout
      @lock.synchronize do
        loop do
          cv_timeout = timeout == :never ? nil : deadline - Time.now
          if !condition_predicate.call && cv_timeout.to_f >= 0
            cv.wait(@lock, cv_timeout)
          end
          if condition_predicate.call
            return yield
          elsif deadline == :never || deadline > Time.now
            next
          else
            return timeout_policy.call
          end
        end
      end
    end
  end
end
