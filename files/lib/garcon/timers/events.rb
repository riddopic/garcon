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

require 'forwardable'
require 'hitimes'
require_relative 'timer'

module Garcon
  module Timers
    # Maintains an ordered list of events, which can be cancelled.
    #
    class Events
      # Represents a cancellable handle for a specific timer event.
      #
      class Handle
        def initialize(time, callback)
          @time = time
          @callback = callback
        end

        # The absolute time that the handle should be fired at.
        attr :time

        # Cancel this timer, O(1).
        def cancel!
          @callback = nil
        end

        # Has this timer been cancelled? Cancelled timer's don't fire.
        #
        def cancelled?
          @callback.nil?
        end

        def > other
          @time > other.to_f
        end

        def to_f
          @time
        end

        # Fire the callback if not cancelled with the given time parameter.
        def fire(time)
          if @callback
            @callback.call(time)
          end
        end
      end

      # A sequence of handles, maintained in sorted order, future to present.
      # @sequence.last is the next event to be fired.
      def initialize
        @sequence = []
      end

      # Add an event at the given time.
      def schedule(time, callback)
        handle = Handle.new(time.to_f, callback)

        index = bisect_left(@sequence, handle)

        # Maintain sorted order, O(logN) insertion time.
        @sequence.insert(index, handle)

        return handle
      end

      # Returns the first non-cancelled handle.
      def first
        while handle = @sequence.last
          if handle.cancelled?
            @sequence.pop
          else
            return handle
          end
        end
      end

      # Returns the number of pending (possibly cancelled) events.
      def size
        @sequence.size
      end

      # Fire all handles for which Handle#time is less than the given time.
      def fire(time)
        pop(time).reverse_each do |handle|
          handle.fire(time)
        end
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      # Efficiently take k handles for which Handle#time is less than the given
      # time.
      def pop(time)
        index = bisect_left(@sequence, time)

        return @sequence.pop(@sequence.size - index)
      end

      # Return the left-most index where to insert item e, in a list a, assuming
      # a is sorted in descending order.
      def bisect_left(a, e, l = 0, u = a.length)
        while l < u
          m = l + (u-l).div(2)

          if a[m] > e
            l = m+1
          else
            u = m
          end
        end

        return l
      end
    end
  end
end
