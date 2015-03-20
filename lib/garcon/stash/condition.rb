# encoding: UTF-8
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

module Garcon
  # Condition is a better implementation of standard Ruby ConditionVariable. The
  # biggest difference is the wait return value: Condition#wait returns
  # Condition::Result which make possible to know if waiting thread has been
  # woken up by an another thread (using #signal or #broadcast) or due to
  # timeout.
  #
  # Every #wait must be guarded by a locked Mutex or a ThreadError will be
  # risen. Although it's not mandatory, it's recommended to call also #signal
  # and #broadcast within the same mutex
  #
  class Condition

    class Result
      def initialize(remaining_time)
        @remaining_time = remaining_time
      end

      attr_reader :remaining_time

      # @return [Boolean] true if current thread has been waken up by a #signal
      #  or a #broadcast call , otherwise false
      def woken_up?
        @remaining_time.nil? || @remaining_time > 0
      end
      alias_method :can_wait?, :woken_up?

      # @return [Boolean] true if current thread has been waken up due to a
      #   timeout, otherwise false
      def timed_out?
        @remaining_time != nil && @remaining_time <= 0
      end
    end

    def initialize
      @condition = ConditionVariable.new
    end

    # @param [Mutex] mutex the locked mutex guarding the wait
    # @param [Object] timeout nil means no timeout
    # @return [Result]
    def wait(mutex, timeout = nil)
      start_time = clock_time
      @condition.wait(mutex, timeout)

      if timeout.nil?
        Result.new(nil)
      else
        Result.new(start_time + timeout - clock_time)
      end
    end

    # Wakes up a waiting thread
    # @return [true]
    def signal
      @condition.signal
      true
    end

    # Wakes up all waiting threads
    # @return [true]
    def broadcast
      @condition.broadcast
      true
    end

    private

    if defined?(Process::CLOCK_MONOTONIC)
      def clock_time
        Process.clock_gettime Process::CLOCK_MONOTONIC
      end
    elsif RUBY_PLATFORM == 'java'
      def clock_time
        java.lang.System.nanoTime() / 1_000_000_000.0
      end
    else
      def clock_time
        Time.now.to_f
      end
    end
  end
end
