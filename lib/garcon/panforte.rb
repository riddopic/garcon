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

require 'openssl'
require 'base64'
require 'thread'
require 'securerandom'

module Garcon
  module Provider
    # More sweetness syntactical sugar for our Pâtissier.
    #
    module Panforte
      include Garcon::Exceptions
      include Chef::Mixin::ShellOut

      # Returns a salted PBKDF2 hash of the password.
      #
      # @param password [String]
      #   password to hash
      #
      # @return [String]
      #   salted PBKDF2 hash of the password provided.
      #
      def hash_salt(password)
        salt = SecureRandom.base64(24)
        pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, salt, 1000, 24)
        Base64.encode64(pbkdf2)
      end

      # Runs a code block, and retries it when an exception occurs. Should the
      # number of retries be reached without success, the last exception will be
      # raised.
      #
      # @param opts [Hash]
      #
      # @option opts [Fixnum] :tries
      #   number of attempts to retry before raising the last exception
      #
      # @option opts [Fixnum] :sleep
      #   number of seconds to wait between retries, use lambda to exponentially
      #   increasing delay between retries
      #
      # @option opts [Array(Exception)] :on
      #   the type of exception(s) to catch and retry on
      #
      # @option opts [Regex] :matching
      #   match based on the exception message
      #
      # @option opts [Block] :ensure
      #   ensure a block of code is executed, regardless of whether an exception
      #   is raised
      #
      # @yield [Proc]
      #   a block that will be run, and if it raises an error, re-run until
      #   success, or timeout is finally reached
      #
      # @raise [Exception]
      #   last Exception that caused the loop to retry before giving up
      #
      # @return [Proc]
      #   the value of the passed block.
      #
      def retrier(options = {}, &_block)
        tries  = options.fetch(:tries,              4)
        wait   = options.fetch(:sleep, ->(n) { 4**n })
        on     = options.fetch(:on,     StandardError)
        match  = options.fetch(:match,           /.*/)
        insure = options.fetch(:insure,       proc {})

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
      module_function :retrier

      # Method usefule for knowing when something is ready. When your block
      # yields true, execution continues. When your block yields false, keep
      # trying until it gives up and raises an error.
      #
      # @example
      #   def wait_for_server
      #     poll(20) do
      #       begin
      #         TCPSocket.new(SERVER_IP, SERVER_PORT)
      #         true
      #       rescue Exception
      #         false
      #       end
      #     end
      #   end
      #
      # @param [Integer] wait
      #   seconds number of seconds to poll
      #
      # @param [Integer] delay
      #   seconds to wait after encountering a failure, default is 0.1 seconds
      #
      # @yield a block that determines whether polling should continue
      #
      # @yield return false if polling should continue
      #
      # @yield return true if polling is complete
      #
      # @raise [Garcon::PollingError] when polling fails
      #
      # @return [Proc]
      #   the value of the passed block.
      #
      def poll(wait = 8, delay = 0.1)
        try_until = Time.now + wait
        failure   = nil

        while Time.now < try_until do
          result = yield
          return result if result
          sleep delay
        end
        raise TimeoutError
      end
      module_function :poll

      # Runs a code block, if an exception occurs wait for some amount of time
      # then retry until success or a timeout is reached, raising the most
      # recent exception.
      #
      # @param [Integer] seconds
      #   number of seconds to be patient, default is 8 seconds
      #
      # @param [Integer] delay
      #   seconds to wait after encountering a failure, default is 0.1 seconds
      #
      # @yield a block that will be run, and if it raises an error, re-run until
      #   success, or patience runs out
      #
      # @raise [Exception] the most recent Exception that caused the loop to
      #   retry before giving up.
      #
      # @return [Proc]
      #   the value of the passed block.
      #
      def patiently(wait = 8, delay = 0.1)
        try_until = Time.now + wait
        failure   = nil

        while Time.now < try_until do
          begin
            return yield
          rescue Exception => e
            failure = e
            sleep delay
          end
        end
        raise failure if failure
      end
      module_function :patiently

      # Wait the given number of seconds for the block operation to complete.
      #
      # @param [Integer] seconds
      #   number of seconds to wait
      #
      # @return [Object]
      #   result of the block operation
      #
      # @raise [Garcon::TimeoutError]
      #   when the block operation does not complete in the alloted time
      #
      def timeout(seconds)
        thread = Thread.new  { Thread.current[:result] = yield }
        thread.join(seconds) ? (return thread[:result]) : (raise TimeoutError)
      ensure
        Thread.kill(thread) unless thread.nil?
      end
      module_function :timeout

      # Return a cleanly join URI/URL segments into a cleanly normalized URL
      # that the libraries can use when constructing URIs. URI.join is pure
      # evil.
      #
      # @param [Array<String>] paths
      #   the list of parts to join
      #
      # @return [URI]
      #
      def uri_join(*paths)
        return nil if paths.length == 0
        leadingslash = paths[0][0] == '/' ? '/' : ''
        trailingslash = paths[-1][-1] == '/' ? '/' : ''
        paths.map! { |path| path.sub(/^\/+/, '').sub(/\/+$/, '') }
        leadingslash + paths.join('/') + trailingslash
      end

      # Returns a hash using col1 as keys and col2 as values.
      #
      # @example zip_hash([:name, :age, :sex], ['Earl', 30, 'male'])
      #   => { :age => 30, :name => "Earl", :sex => "male" }
      #
      # @param [Array] col1
      #   Containing the keys.
      #
      # @param [Array] col2
      #   Values for hash.
      #
      # @return [Hash]
      #
      def zip_hash(col1, col2)
        col1.zip(col2).inject({}) { |r, i| r[i[0]] = i[1]; r }
      end

      # Returns true if the current node is a docker container, otherwise false.
      #
      # @return [TrueClass, FalseClass]
      #
      def docker?
        ::File.exist?('/.dockerinit') || ::File.exist?('/.dockerenv')
      end

      # Returns true if the current node has selinux enabled, otherwise false.
      #
      # @return [TrueClass, FalseClass]
      #
      def selinux?
        if installed?('libselinux-utils')
          Mixlib::ShellOut.new('getenforce').run_command.stdout != "Disabled\n"
        else
          false
        end
      end

      # Finds a command in $PATH
      #
      # @param [String] cmd
      #   the command to find
      #
      # @return [String, nil]
      #
      def which(cmd)
        if Pathname.new(cmd).absolute?
          File.executable?(cmd) ? cmd : nil
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

      # Retrieve the version number of the cookbook in the run list.
      #
      # @param name [String]
      #   name of cookbook to retrieve the version on.
      #
      # @return [Integer]
      #   version of the cookbook.
      #
      # @api public
      def cookbook_version(name = nil)
        cookbook = name.nil? ? cookbook_name : name
        node.run_context.cookbook_collection[cookbook].metadata.version
      end

      # Boolean method to check if a command line utility is installed.
      #
      # @param [String] cmd
      #   the command to find
      #
      # @return [TrueClass, FalseClass]
      #   true if the command is found in the path, false otherwise
      #
      # @api public
      def installed?(cmd)
        !which(cmd).nil?
      end

      # Monitor for thread safety
      #
      # @api public
      def monitor
        @monitor ||= Monitor.new
      end

      # Creates a temp directory executing the block provided. When done the
      # temp directory and all it's contents are garbage collected.
      #
      # @param block [Block]
      #
      # @api public
      def with_tmp_dir(&block)
        Dir.mktmpdir(SecureRandom.hex(3)) do |tmp_dir|
          Dir.chdir(tmp_dir, &block)
        end
      end

      # Shortcut to return cache path, if you pass in a file it will return the
      # file with the cache path.
      #
      # @example
      #   file_cache_path
      #     => "/var/chef/cache/"
      #
      #   file_cache_path 'patch.tar.gz'
      #     => "/var/chef/cache/patch.tar.gz"
      #
      #   file_cache_path "#{node[:name]}-backup.tar.gz"
      #     => "/var/chef/cache/c20d24209cc8-backup.tar.gz"
      #
      # @param [String] args
      #   name of file to return path with file
      #
      # @return [String]
      #
      def file_cache_path(*args)
        if args.nil?
          Chef::Config[:file_cache_path]
        else
          ::File.join(Chef::Config[:file_cache_path], args)
        end
      end

      # Amazingly and somewhat surprisingly comma separate a number
      #
      # @param [Integer] num
      #
      # @return [String]
      #
      def comma_separate(num)
        num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
      end

      # Unshorten a shortened URL
      #
      # @param url [String] A shortened URL
      #
      # @param [Hash] opts
      #
      # @option opts [Integer] :max_level
      #   max redirect times
      #
      # @option opts [Integer] :timeout
      #   timeout in seconds, for every request
      #
      # @option opts [TrueClass, FalseClass] :use_cache
      #   use cached result if available
      #
      # @return Original url, a url that does not redirects
      #
      def unshorten(url, opts= {})
        options = {
          max_level: opts.fetch(:max_level,   10),
          timeout:   opts.fetch(:timeout,      2),
          use_cache: opts.fetch(:use_cache, true)
        }
        url = (url =~ /^https?:/i) ? url : "http://#{url}"
        __unshorten__(url, options)
      end

      private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

      @@cache = { }

      # @api private
      def __unshorten__(url, options, level = 0)
        return @@cache[url] if options[:use_cache] && @@cache[url]
        return url if level >= options[:max_level]
        uri = URI.parse(url) rescue nil
        return url if uri.nil?

        http = Net::HTTP.new(uri.host, uri.port)
        http.open_timeout = options[:timeout]
        http.read_timeout = options[:timeout]
        http.use_ssl = true if uri.scheme == 'https'

        if uri.path && uri.query
          response = http.request_head("#{uri.path}?#{uri.query}") rescue nil
        elsif uri.path && !uri.query
          response = http.request_head(uri.path) rescue nil
        else
          response = http.request_head('/') rescue nil
        end

        if response.is_a? Net::HTTPRedirection and response['location'] then
          location = URI.encode(response['location'])
          location = (uri + location).to_s if location
          @@cache[url] = __unshorten__(location, options, level + 1)
        else
          url
        end
      end

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
  end
end
