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

require 'monitor'
require 'socket'

module Garcon

  # A port number to bind to, dynamic port numbers are in the highest range,
  # from 49152 through 65535. Port numbers are divided into three ranges: the
  # Well Known Ports are those from 0 through 1023, the Registered Ports are
  # those from 1024 through 49151 and the Dynamic and/or Private Ports are
  # those from 49152 through 65535. The default is to chose a random port
  # number in the dynamic range.
  PORT = rand(49152..65535)

  # Creates a new socket on the given interface. The network interface can be
  # a string such as `localhost`, which can be a host name, a dotted-quad
  # address, or an IPV6 address in colon (and possibly dot) notation. The
  # default value is `127.0.0.1`.
  INTERFACE = '127.0.0.1'

  # Number of seconds to wait for the lock to terminate. Any number may be
  # used, including Floats to specify fractional seconds. A value of 0 or nil
  # will execute the block without any timeout. The default is `15 * 60`, 900
  # seconds, or 15 minutes.
  TIMEOUT = 15 * 60

  class Lock
    include Garcon::Utils

    # @return [Integer] timeout.
    attr_reader :timeout

    # @return [Integer] port number used for the TCP socket.
    attr_reader :port

    # @return [String] interface used for the TCP socket.
    attr_reader :interface

    # @return [TrueClass, FalseClass] if we have a lock.
    attr_reader :locked

    # Creates a new instance of `Garcon::Lock`.
    #
    # @param [Integer] port number to bind to, the default behavor is to bind to
    #   a random port number from 49152 through 65535.
    # @param [String] interface to create a socket on, can be a hostname such as
    #   `localhost` or an IP address.
    # @param [Integer] timeout in seconds that will be allowed to elapse waiting
    #   for the lock.
    #
    # @raise [Timeout::Error] execution expired.
    #
    # @return [TCPSocket]
    #
    def initialize(port:PORT, interface:INTERFACE, timeout:TIMEOUT)
  		@port = port
  		@interface = interface
  		@locked = false
  		@unlock_code = 'unlock'
  		@timeout = timeout
  		@monitor = Monitor.new
  		@unlock_thread = nil
  		@condition = Condition.new
      log.debug "Instance #{log_prefix} called"
    end

    # Set a lock then yield the block, ensuring that the lock is released.
    #
    # @return [Object] the value of the block
    def synchronize(*args, &block)
      @monitor.synchronize do
        begin
          Garcon::timeout(@timeout) do
            lock
            yield if block_given?
          end
        rescue Timeout::Error
          log.debug 'Timeout::Error waiting for lock'
        ensure
          unlock
        end
      end
    end

  	def lock
  		@monitor.synchronize do
        return if locked? # we already have it
  			Garcon::timeout(@timeout) do
    			log.debug "Creating lock on #{@interface}:#{@port}"
  				while true
  					begin
  						@server = TCPServer.new(@interface, @port)
  						@locked = true
  						log.debug "#{@server} has a lock"
  						break
  					rescue
  						# Whoops... still not ours
  						sleep(1.0)
  					end
  				end
  			end # timeout(@timeout)

  			# Watch for unlock requests
  			@unlock_thread = Thread.new do
  				while true
  					begin
  						socket = @server.accept
  						@monitor.synchronize do
  							code = socket.gets.strip
  							begin socket.close; rescue; end
  							if code == @unlock_code
    							log.debug "received an unlock request for #{socket}"
  								@locked = false
  								@condition.broadcast
  								@unlock_thread = nil
  								@server.close
  								break
  							end
  						end
  					rescue
  						# Getting conn probs. We're just ignoring it.
  						sleep(0.5)
  					end
  				end
  			end # @unlock_thread
  		end # @monitor.synchronize
  	end # def lock

  	def unlock
  		@monitor.synchronize do
  			if locked?
  				socket = TCPSocket.new(@interface, @port)
  				log.debug "unlocking #{@socket}"
  				socket.puts @unlock_code
  				socket.close
  				@condition.broadcast
  				sleep(0.5) # Give it a chance
  			end
  		end
  	end

  	def locked?
  		@monitor.synchronize { return @locked }
  	end
  end
end
