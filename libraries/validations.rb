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
require_relative 'exceptions'

# Resource validations.
#
module Garcon
  module Resource
    module Validations
      module ClassMethods
        include Garcon::Exceptions

        # Boolean, true if port number is within range, otherwise raises a
        # Exceptions::InvalidPort
        #
        # @param [Integer] port
        # @param [Range<Integer>] range
        # @return [Trueclass]
        # @raise [ValidationError]
        # @api private
        def valid_port?(port, range = 0..65_535)
          (range === port) ? true : (raise ValidationError.new port, range)
        end

        # Validate the hostname, returns the IP address if valid, otherwise
        # raises Exceptions::InvalidHost
        #
        # @param [String] host
        # @return [Integer]
        # @raise [ValidationError]
        # @api private
        def validate_host(host)
          IPSocket.getaddress(host)
        rescue
          raise ValidationError
        end

        # Validate that the path specified is a file or directory, will raise
        # Exceptions::InvalidFilePath if not
        #
        # @param [String] path
        # @param [Symbol] id_a
        #   the type to validate, valid types are `:file` or `:dir`
        # @return [TrueClass]
        # @raise [ValidationError]
        # @api private
        def validate_path(path, is_a = :file)
          file, dir = ::File.exist?(path), Dir.exist?(path)
          unless is_a == :file ? file : is_a == :dir ? dir : nil
            raise ValidationError, "#{path} is not a valid #{is_a}"
          end
        end

        # Validate that the source attribute is an absolute URI or file and not
        # an not empty string.
        #
        # @param [Array, String]
        # @return [Trueclass]
        # @raise [ValidationError]
        # @api private
        def validate_source(source)
          Array(source).flatten.each do |src|
            unless ::File.exist?(src) || absolute_uri?(src)
              raise ValidationError, "Invalid source #{src.inspect}"
            end
          end
          true
        end

        # Boolean, true if source is an absolute URI, false otherwise.
        #
        # @param [String] source
        # @return [Trueclass, Falseclass]
        # @api private
        def absolute_uri?(source)
          source.kind_of?(String) && URI.parse(source).absolute?
        rescue URI::InvalidURIError
          false
        end

        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
        #
        # @api private
        def included(klass)
          super
          klass.extend ClassMethods
        end
      end
      extend ClassMethods
    end
  end
end
