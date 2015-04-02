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
  # Hash that allows you to access keys of the hash via method calls This gives
  # you an OStruct like way to access your hash's keys. It will recognize keys
  # either as strings or symbols.
  #
  class StashCache < Hash
    include Garcon::Extensions::MethodReader
    include Garcon::Extensions::PrettyInspect
  end

  # In-process cache with least-recently used (LRU) and time-to-live (TTL)
  # expiration semantics.
  #
  # This implementation is thread-safe. It does not use a thread to clean
  # up expired values. Instead, an expiration check is performed:
  #
  # 1. Every time you retrieve a value, against that value. If the value has
  #    expired, it will be removed and `nil` will be returned.
  #
  # 2. Every `expire_interval` operations as the cache is used to remove all
  #    expired values up to that point.
  #
  # For manual expiration call {#expire!}.
  #
  # @example
  #
  #   # Create cache with one million elements no older than 1 hour
  #   cache = FastCache::Cache.new(1_000_000, 60 * 60)
  #   cached_value = cache.fetch('cached_value_key') do
  #     # Expensive computation that returns the value goes here
  #   end
  #
  class MemStash

    # Initializes the cache.
    #
    # @param [Integer] max_size
    #   Maximum number of elements in the cache.
    #
    # @param [Numeric] ttl
    #   Maximum time, in seconds, for a value to stay in the cache.
    #
    # @param [Integer] expire_interval
    #   Number of cache operations between calls to {#expire!}.
    #
    def initialize(max_size = 10_000, ttl = 60*60, expire_interval = 100)
      @max_size        = max_size
      @ttl             = ttl.to_f
      @expire_interval = expire_interval
      @op_count        = 0
      @stash           = StashCache.new
      @expires_at      = {}
      @monitor         = Monitor.new
    end

    # Loads a hash of data into the stash.
    #
    # @param hash [Hash] of data with either String or Symbol keys.
    #
    # @return nothing.
    #
    def load(data)
      @monitor.synchronize do
        data.each do |key, value|
          expire!
          store(key, val)
        end
      end
    end

    # Retrieves a value from the cache, if available and not expired, or yields
    # to a block that calculates the value to be stored in the cache.
    #
    # @param [Object] key
    #   The key to look up or store at.
    #
    # @yield yields when the value is not present.
    #
    # @yieldreturn [Object]
    #   The value to store in the cache.
    #
    # @return [Object]
    #   The value at the key.
    #
    def fetch(key)
      @monitor.synchronize do
        found, value = get(key)
        found ? value : store(key, yield)
      end
    end

    # Retrieves a value from the cache.
    #
    # @param [Object] key
    #   The key to look up.
    #
    # @return [Object, nil]
    #   The value at the key, when present, or `nil`.
    #
    def [](key)
      @monitor.synchronize do
        _, value = get(key)
        value
      end
    end
    alias_method :get, :[]

    # Stores a value in the cache.
    #
    # @param [Object] key
    #   The key to store.
    #
    # @param val [Object]
    #   The value to store.
    #
    # @return [Object, nil]
    #   The value at the key.
    #
    def []=(key, val)
      @monitor.synchronize do
        expire!
        store(key, val)
      end
    end
    alias_method :set, :[]=

    # Removes a value from the cache.
    #
    # @param [Object] key
    #   The key to remove.
    #
    # @return [Object, nil]
    #   The value at the key, when present, or `nil`.
    #
    def delete(key)
      @monitor.synchronize do
        entry = @stash.delete(key)
        if entry
          @expires_at.delete(entry)
          entry.value
        else
          nil
        end
      end
    end

    # Checks whether the cache is empty.
    #
    # @note calls to {#empty?} do not count against `expire_interval`.
    #
    # @return [Boolean]
    #
    def empty?
      @monitor.synchronize { count == 0 }
    end

    # Clears the cache.
    #
    # @return [self]
    #
    def clear
      @monitor.synchronize do
        @stash.clear
        @expires_at.clear
        self
      end
    end

    # Returns the number of elements in the cache.
    #
    # @note
    #   Calls to {#empty?} do not count against `expire_interval`. Therefore,
    #   the number of elements is that prior to any expiration.
    #
    # @return [Integer]
    #   Number of elements in the cache.
    #
    def count
      @monitor.synchronize { @stash.count }
    end
    alias_method :size, :count
    alias_method :length, :count

    # Allows iteration over the items in the cache.
    #
    # Enumeration is stable: it is not affected by changes to the cache,
    # including value expiration. Expired values are removed first.
    #
    # @note
    #   The returned values could have expired by the time the client code gets
    #   to accessing them.
    #
    # @note
    #   Because of its stability, this operation is very expensive. Use with
    #   caution.
    #
    # @yield [Array<key, value>]
    #   Key/value pairs, when a block is provided.
    #
    # @return [Enumerator, Array<key, value>]
    #   An Enumerator, when no block is provided, or array of key/value pairs.
    #
    def each(&block)
      @monitor.synchronize do
        expire!
        @stash.map { |key, entry| [key, entry.value] }.each(&block)
      end
    end

    # Removes expired values from the cache.
    #
    # @return [self]
    #
    def expire!
      @monitor.synchronize do
        check_expired(Time.now.to_f)
        self
      end
    end

    # return all keys in the store as an array
    #
    # @return [Array<String, Symbol>] all the keys in store
    #
    def keys
      @monitor.synchronize { @stash.keys }
    end

    # Returns information about the number of objects in the cache, its
    # maximum size and TTL.
    #
    # @return [String]
    #
    def inspect
      @monitor.synchronize do
        "<#{self.class.name} count=#{count} max_size=#{@max_size} ttl=#{@ttl}>"
      end
    end

    private #        P R O P R I E T À   P R I V A T A   Vietato L'accesso

    # @private
    class Entry
      attr_reader :value
      attr_reader :expires_at

      def initialize(value, expires_at)
        @value = value
        @expires_at = expires_at
      end
    end

    def get(key)
      @monitor.synchronize do
        t = Time.now.to_f
        check_expired(t)
        found = true
        entry = @stash.delete(key) { found = false }
        if found
          if entry.expires_at <= t
            @expires_at.delete(entry)
            return false, nil
          else
            @stash[key] = entry
            return true, entry.value
          end
        else
          return false, nil
        end
      end
    end

    def store(key, val)
      @monitor.synchronize do
        expires_at = Time.now.to_f + @ttl
        entry = Entry.new(val, expires_at)
        store_entry(key, entry)
        val
      end
    end

    def store_entry(key, entry)
      @monitor.synchronize do
        @stash.delete(key)
        @stash[key] = entry
        @expires_at[entry] = key
        shrink_if_needed
      end
    end

    def shrink_if_needed
      @monitor.synchronize do
        if @stash.length > @max_size
          entry = delete(@stash.shift)
          @expires_at.delete(entry)
        end
      end
    end

    def check_expired(t)
      @monitor.synchronize do
        if (@op_count += 1) % @expire_interval == 0
          while (key_value_pair = @expires_at.first) &&
              (entry = key_value_pair.first).expires_at <= t
            key = @expires_at.delete(entry)
            @stash.delete(key)
          end
        end
      end
    end
  end
end
