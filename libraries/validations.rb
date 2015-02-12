# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: helpers
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

require 'ipaddr'
require 'openssl'
require 'base64'
require 'securerandom'

# Helper methods for cookbook.
#
module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Validations
    # Matches on a string.
    STRING_VALID_REGEX = /\A[^\\\/\:\*\?\<\>\|]+\z/

    # Matches on a file mode.
    FILE_MODE_VALID_REGEX = /^0?\d{3,4}$/

    # Matches on a MD5/SHA-1/256 checksum.
    CHECKSUM_VALID_REGEX = /^[0-9a-f]{32}$|^[a-zA-Z0-9]{40,64}$/

    # Matches on a URL/URI with a archive file link.
    URL_ARCH_VALID_REGEX = /^(file|http|https?):\/\/.*(gz|tar.gz|tgz|bin|zip)$/

    # Matches on a FQDN like name (does not validate FQDN).
    FQDN_VALID_REGEX = /^(?:(?:[0-9a-zA-Z_\-]+)\.){2,}(?:[0-9a-zA-Z_\-]+)$/

    # Matches on a valid IPV4 address.
    IPV4_VALID_REGEX = /\b(25[0-5]|2[0-4]\d|1\d\d|
                        [1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b/

    # Matches on port ranges 0 to 1023.
    VALID_PORTS_REGEX = /^(102[0-3]|10[0-1]\d|[1-9][0-9]{0,2}|0)$/

    # Matches on any port from 0 to 65_535.
    PORTS_ALL_VALID_REGEX = /^(6553[0-5]|655[0-2]\d|65[0-4]\d\d|6[0-4]\d{3}|
                             [1-5]\d{4}|[1-9]\d{0,3}|0)$/
    class << self
      # Helper method to validate port numbers
      #
      # @yield [Integer]
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidPort]
      # @api private
      def port?
        ->(port) { validate_port(port) }
      end

      # Boolean, true if port number is within range, otherwise raises a
      # Exceptions::InvalidPort
      #
      # @param [Integer] port
      # @param [Range<Integer>] range
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidPort]
      # @api private
      def valid_port?(port, range = 0..65_535)
        (range === port) ? true : (fail InvalidPort.new port, range)
      end

      # Helper method to validate host name
      #
      # @yield [Integer]
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidHost]
      # @api private
      def host?
        ->(_host) { validate_host(name) }
      end

      # Validate the hostname, returns the IP address if valid, otherwise raises
      # Exceptions::InvalidHost
      #
      # @param [String] host
      # @return [Integer]
      # @raise [Odsee::Exceptions::InvalidHost]
      # @api private
      def validate_host(host)
        IPSocket.getaddress(host)
      rescue
        raise InvalidHost.new host
      end

      # Helper method to validate file
      #
      # @yield [Integer]
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidFile]
      # @api private
      def file?
        ->(file) { validate_file(file) }
      end

      # Boolean, true if file exists, otherwise raises a Exceptions::InvalidFile
      #
      # @param [String] file
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidFile]
      # @api private
      def valid_file?(file)
        ::File.exist?(file) ? true : (fail FileNotFound.new file)
      end

      # Helper method to validate file path
      #
      # @yield [Integer]
      # @return [Trueclass]
      # @raise [Odsee::Exceptions::InvalidFilePath]
      # @api private
      def path?
        ->(_path) { validate_filepath(file) }
      end

      # Validate that the path specified is a file or directory, will raise
      # Exceptions::InvalidFilePath if not
      #
      # @param [String] path
      # @return [TrueClass]
      # @raise [Odsee::Exceptions::InvalidFilePath]
      # @api private
      def validate_filepath?(path)
        unless ::File.exist?(path) || ::File.directory?(path)
          fail PathNotFound.new path
        end
      end
    end
  end
end
