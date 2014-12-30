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

module Garcon

  # Wait the given number of seconds for the block operation to complete.
  # @note This method is intended to be a simpler and more reliable replacement
  # to the Ruby standard library `Timeout::timeout` method.
  #
  # @param [Integer] seconds The number of seconds to wait
  #
  # @return [Object] The result of the block operation
  #
  # @raise [Garcon::TimeoutError] when the block operation does not complete
  #   in the allotted number of seconds.
  #
  def timeout(seconds)
    thread = Thread.new { Thread.current[:result] = yield }
    success = thread.join(seconds)

    if success
      thread[:result]
    else
      raise TimeoutError
    end
  ensure
    Thread.kill(thread) unless thread.nil?
  end
  module_function :timeout
end
