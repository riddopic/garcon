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
  # Basic cache object stash store (uses a Hash)
  #
  class MemStash

    # @return [Hash] of the mem stash cache hash store
    #
    attr_reader :store

    # Initializes a new store object.
    #
    # @param data [Hash] (optional) data to load into the stash.
    #
    # @return nothing.
    #
    def initialize(_ = {})
      @store = {}
    end

    # Clear the whole stash store or the value of a key
    #
    # @param key [Symbol, String] (optional) representing the key to
    # clear.
    #
    # @return nothing.
    #
    def clear!(key = nil)
      key.nil? ? @store.clear : @store.delete(key)
    end

    # Retrieves the value for a given key, if nothing is set,
    # returns KeyError
    #
    # @param key [Symbol, String] representing the key
    #
    # @raise [KeyError] if no such key found
    #
    # @return [Hash, Array, String] value for key
    #
    def [](key)
      @store[key]
    end
    alias_method :get, :[]

    # Store the given value with the given key, either an an argument
    # or block. If a previous value was set it will be overwritten
    # with the new value.
    #
    # @param key [Symbol, String] string or symbol representing the key
    # @param value [Object] any object that represents the value (optional)
    # @param block [&block] that returns the value to set (optional)
    #
    # @return nothing.
    #
    def []=(key, value)
      @store[key] = value
    end
    alias_method :set, :[]=

    # Loads a hash of data into the stash.
    #
    # @param hash [Hash] of data with either String or Symbol keys.
    #
    # @return nothing.
    #
    def load(data)
      data.each do |key, value|
        @store[key] = value
      end
    end

    # return the size of the store as an integer
    #
    # @return [Fixnum]
    #
    def size
      @store.size
    end

    # return a boolean indicating presence of the given key in the store
    #
    # @param key [Symbol, String] a string or symbol representing the key
    #
    # @return [TrueClass, FalseClass]
    #
    def include?(key)
      @store.include? key
    end
    alias_method :key?, :include?

    # return all keys in the store as an array
    #
    # @return [Array<String, Symbol>] all the keys in store
    #
    def keys
      @store.keys
    end
  end
end
