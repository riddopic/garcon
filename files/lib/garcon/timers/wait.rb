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

require 'hitimes'

module Garcon
  module Timers
    # An exclusive, monotonic timeout class.
    class Wait
      def self.for(duration, &block)
        if duration
          timeout = self.new(duration)

          timeout.while_time_remaining(&block)
        else
          while true
            yield(nil)
          end
        end
      end

      def initialize(duration)
        @duration = duration
        @remaining = true
      end

      attr :duration
      attr :remaining

      # Yields while time remains for work to be done:
      def while_time_remaining(&block)
        @interval = Hitimes::Interval.new
        @interval.start

        while time_remaining?
          yield @remaining
        end
      ensure
        @interval.stop
        @interval = nil
      end

      private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

      def time_remaining?
        @remaining = (@duration - @interval.duration)

        return @remaining > 0
      end
    end
  end
end
