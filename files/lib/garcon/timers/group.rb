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

require 'set'
require 'forwardable'
require 'hitimes'
require_relative 'timer'
require_relative 'events'

module Garcon
  # Ruby timer collections. Schedule several procs to fire after configurable
  # delays or at periodic intervals.
  #
  # @example schedule a proc to run after 5 seconds:
  #   timers = Garcon::Timers::Group.new
  #   five_second_timer = timers.after(5) { puts 'Five seconds' }
  #   timers.wait
  #     # => Five seconds
  #
  # @example schedule a block to run periodically:
  #   every_five_seconds = timers.every(5) { puts 'Another five seconds' }
  #   loop { timers.wait }
  #     # => Another five seconds
  #     # => Another five seconds
  #     # => Another five seconds
  #
  # @example if you'd like another method to do the waiting for you, e.g.
  #   `Kernel.select`, you can use `Garcon::Timers::Group#wait_interval` to
  #   obtain the amount of time to wait. When a timeout is encountered, you can
  #   fire all pending timers with `Garcon::Timers::Group#fire`:
  #     loop do
  #       interval = timers.wait_interval
  #       ready_readers, ready_writers = select readers, writers, nil, interval
  #       if ready_readers || ready_writers
  #         # Handle IO
  #         ...
  #       else
  #         # Timeout!
  #         timers.fire
  #       end
  #     end
  #
  module Timers
    class Group
      include Enumerable

      extend Forwardable
      def_delegators :@timers, :each, :empty?

      def initialize
        @events        = Events.new
        @timers        = Set.new
        @paused_timers = Set.new
        @interval      = Hitimes::Interval.new
        @interval.start
      end

      # Scheduled events:
      attr :events

      # Active timers:
      attr :timers

      # Paused timers:
      attr :paused_timers

      # Call the given block after the given interval. The first argument will
      # be the time at which the group was asked to fire timers for.
      #
      def after(interval, &block)
        Timer.new(self, interval, false, &block)
      end

      # Call the given block periodically at the given interval. The first
      # argument will be the time at which the group was asked to fire timers
      # for.
      #
      def every(interval, recur = true, &block)
        Timer.new(self, interval, recur, &block)
      end

      # Wait for the next timer and fire it. Can take a block, which should
      # behave like sleep(n), except that n may be nil (sleep forever) or a
      # negative number (fire immediately after return).
      def wait(&block)
        if block_given?
          yield wait_interval

          while interval = wait_interval and interval > 0
            yield interval
          end
        else
          while interval = wait_interval and interval > 0
            sleep interval
          end
        end

        fire
      end

      # Interval to wait until when the next timer will fire.
      # - nil: no timers
      # - -ve: timers expired already
      # -   0: timers ready to fire
      # - +ve: timers waiting to fire
      #
      def wait_interval(offset = self.current_offset)
        if handle = @events.first
          return handle.time - Float(offset)
        end
      end

      # Fire all timers that are ready.
      #
      def fire(offset = self.current_offset)
        @events.fire(offset)
      end

      # Pause all timers.
      #
      def pause
        @timers.dup.each do |timer|
          timer.pause
        end
      end

      # Resume all timers.
      #
      def resume
        @paused_timers.dup.each do |timer|
          timer.resume
        end
      end

      alias_method :continue, :resume

      # Delay all timers.
      #
      def delay(seconds)
        @timers.each do |timer|
          timer.delay(seconds)
        end
      end

      # Cancel all timers.
      #
      def cancel
        @timers.dup.each do |timer|
          timer.cancel
        end
      end

      # The group's current time.
      #
      def current_offset
        @interval.to_f
      end
    end
  end
end
