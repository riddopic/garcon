# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: cli_helpers
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

# Instance methods that are added when you include Odsee::CliHelpers
#
module Garcon
  module Resource
    module CliHelpers
      module ClassMethods
        # Extends a descendant with class and instance methods
        #
        # @param [Class] descendant
        #
        # @return [undefined]
        #
        # @api private
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end

      extend ClassMethods

      # Returns a hash using col1 as keys and col2 as values.
      #
      # @example zip_hash([:name, :age, :sex], ['Earl', 30, 'male'])
      #   => { :age => 30, :name => "Earl", :sex => "male" }
      #
      # @param [Array] col1
      #   Containing the keys.
      # @param [Array] col2
      #   Values for hash.
      #
      # @return [Hash]
      #
      # @api public
      def zip_hash(col1, col2)
        col1.zip(col2).inject({}) { |r, i| r[i[0]] = i[1]; r }
      end

      # Finds a command in $PATH
      #
      # @param [String] cmd
      #
      # @return [String, NilClass]
      #
      # @api public
      def which(cmd)
        if Pathname.new(cmd).absolute?
          ::File.executable?(cmd) ? cmd : nil
        else
          paths = %w(/bin /usr/bin /sbin /usr/sbin)
          paths << ENV.fetch('PATH').split(::File::PATH_SEPARATOR)
          paths.flatten.uniq.each do |path|
            possible = ::File.join(path, cmd)
            return possible if ::File.executable?(possible)
          end
          nil
        end
      end

      # Runs a code block, and retries it when an exception occurs. Should the
      # number of retries be reached without success, the last exception will be
      # raised.
      #
      # @param opts [Hash{Symbol => Value}]
      # @option opts [Fixnum] :tries
      #   number of attempts to retry before raising the last exception
      # @option opts [Fixnum] :sleep
      #   number of seconds to wait between retries, use lambda to exponentially
      #   increasing delay between retries
      # @option opts [Array(Exception)] :on
      #   the type of exception(s) to catch and retry on
      # @option opts [Regex] :matching
      #   match based on the exception message
      # @option opts [Block] :ensure
      #   ensure a block of code is executed, regardless of whether an exception
      #   is raised
      #
      # @return [Block]
      #
      # @api public
      def retrier(options = {}, &_block)
        tries  = options.fetch(:tries, 4)
        wait   = options.fetch(:sleep, 1)
        on     = options.fetch(:on, StandardError)
        match  = options.fetch(:match, /.*/)
        insure = options.fetch(:insure, proc {})

        retries = 0
        retry_exception = nil

        begin
          yield retries, retry_exception
        rescue *[on] => exception
          raise unless exception.message =~ match
          raise if retries + 1 >= tries

          # Interrupt Exception could be raised while sleeping
          begin
            sleep wait.respond_to?(:call) ? wait.call(retries) : wait
          rescue *[on]
          end

          retries += 1
          retry_exception = exception
          retry
        ensure
          insure.call(retries)
        end
      end
    end
  end
end
