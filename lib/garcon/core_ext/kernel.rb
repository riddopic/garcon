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

# Add #maybe
module Kernel
  # Random generator that returns true or false. Can also take a block that has
  # a 50/50 chance to being executed.
  #
  def maybe(chance = 0.5, &block)
    if block
      yield if rand < chance
    else
      rand < chance
    end
  end

  # Like #respond_to? but returns the result of the call if it does respond.
  #
  #   class RespondExample
  #     def f; "f"; end
  #   end
  #
  #   x = RespondExample.new
  #   x.respond(:f)  #=> "f"
  #   x.respond(:g)  #=> nil
  #
  # This method was known as #try until Rails defined #try
  # to be something more akin to #ergo.
  #
  def respond(sym = nil, *args, &blk)
    if sym
      return nil unless respond_to?(sym)
      __send__(sym, *args, &blk)
    else
      MsgFromGod.new(&method(:respond).to_proc)
    end
  end

  # The opposite of #nil?.
  #
  #   "hello".not_nil?     # -> true
  #   nil.not_nil?         # -> false
  #
  def not_nil?
    ! nil?
  end

  # Temporarily set variables while yielding a block, then return the
  # variables to their original settings when complete.
  #
  #   temporarily('$VERBOSE'=>false) do
  #     $VERBOSE.assert == false
  #   end
  #
  def temporarily(settings)
    cache = {}
    settings.each do |var, val|
      cache[var] = eval("#{var}")
      eval("proc{ |v| #{var} = v }").call(val)
    end
    yield
  ensure
    cache.each do |var, val|
      eval("proc{ |v| #{var} = v }").call(val)
    end
  end
end
