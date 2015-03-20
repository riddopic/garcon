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

require 'garcon/stash/condition'

module Garcon
  module Stash
    # @api private
    class Queue
      def initialize
        @mutex = Mutex.new
        @full  = Garcon::Condition.new
        @empty = Garcon::Condition.new
        @queue = []
      end

      def <<(x)
        @mutex.synchronize do
          @queue << x
          @full.signal
        end
      end

      def pop
        @mutex.synchronize do
          @queue.shift
          @empty.signal if @queue.empty?
        end
      end

      def first
        @mutex.synchronize do
          @full.wait(@mutex) while @queue.empty?
          @queue.first
        end
      end

      def flush
        @mutex.synchronize do
          @empty.wait(@mutex) until @queue.empty?
        end
      end

      def close
      end
    end
  end
end
