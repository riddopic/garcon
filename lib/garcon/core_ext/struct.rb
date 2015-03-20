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

class Pathname
  # same as `#exist?`
  def exists?(*args) exist?(*args) ; end

  # @example It chains nicely:
  #   # put each file in eg. dest/f/foo.json
  #   Pathname.of(:dest, slug[0..0], "#{slug}.json").mkparent.open('w') do |file|
  #     # ...
  #   end
  #
  # @returns the path itself (not its parent)
  def mkparent
    dirname.mkpath
    return self
  end

  # Like find, but returns an enumerable
  #
  def find_all
    Enumerator.new{|yielder| find{|path| yielder << path } }
  end

  #
  # Executes the block (passing the opened file) if the file does not
  # exist. Ignores the block otherwise. The block is required.
  #
  # @param options
  # @option options[:force] Force creation of the file
  #
  # @returns the path itself (not the file)
  def if_missing(options={}, &block)
    ArgumentError.block_required!(block)
    return self if exist? && (not options[:force])
    #
    mkparent
    open((options[:mode] || 'w'), &block)
    return self
  end

end
