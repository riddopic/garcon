# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014 Stefano Harding
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

require 'uri'
require 'thread'
require 'net/http'
require 'digest/sha2'

module Garcon; end
# Helper methods for cookbook.
#
module Garcon::Helpers
  # A set of helper methods shared by all resources and providers.
  #
  def self.included(base)
    include(ClassMethods)

    base.send(:include, ClassMethods)
  end
  private_class_method :included

  module ClassMethods
    # Check to see if the recipe has already been included, if not include it.
    # It will return false if it has already been run or return the last value
    # of the includeed recipe.
    #
    # @param [String] recipe
    #   the recipe to include only once
    #
    # @return [Boolean]
    #   false if it's already been run
    #
    def single_include(recipe)
      node.run_context.loaded_recipe?(recipe) ? false : (include_recipe recipe)
    end

    # Runs the recipe in it's own thread. NOTE: You need to ensure that the
    # recipe is thread safe and non-blocking.
    #
    # @param [String] recipe
    #   the recipe to run
    #
    def threaded_include(recipe)
      thread name { block { run_context.include_recipe recipe }}
    end

    def recipe_block_run(&block)
      @run_context.resource_collection = Chef::ResourceCollection.new
      instance_eval(&block)
      Chef::Runner.new(@run_context).converge
    end

    def recipe_block(description, &block)
      recipe = self
      ruby_block "recipe_block[#{description}]" do
        block { recipe.instance_eval(&block) }
      end
    end

    def recipe_fork(description, &block)
      block_body = proc { fork { recipe_block_run(&block) }}
      recipe_block(description, &block_body)
    end

    def recipe_thread(description, &block)
      block_body = proc { ThreadPool.schedule { recipe_block_run(&block) }}
      recipe_block(description, &block_body)
    end

    # Return a cleanly join URI/URL segments into a cleanly normalized URL that
    # the libraries can use when constructing URIs. URI.join is pure evil.
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
        paths = ENV['PATH'].split(::File::PATH_SEPARATOR) + %w(
          /bin /usr/bin /sbin /usr/sbin)

        paths.each do |path|
          possible = File.join(path, cmd)
          return possible if File.executable?(possible)
        end

        nil
      end
    end

    # Boolean method to check if a command line utility is installed.
    #
    # @param [String] cmd
    #   the command to find
    #
    # @return [Boolean]
    #   true if the command is found in the path, false otherwise
    #
    def installed?(cmd)
      !which(cmd).nil?
    end

    # Provides a very fast HTTP download alternative to remote_file. Using
    # persistent connection for multiple requests provides a huge speed increase
    # since we don’t have to setup connection for each download. Also, we spin
    # up some threads to bring concurrency. There will be a lot of network I/O
    # in these threads which does not lock GIL in Ruby.
    #
    # @param [Array] urls
    #   list of urls with fils to download
    # @param [String] dstdir
    #   directory where to save the downloaded files
    # @param [String] server
    #   name of server to setup persistent connection with
    # @param [Integer] thread_count
    #   number of threads for concurrent requests
    #
    def remote_files(urls, dstdir, server, opts)
      thread_count = opts.fetch(:thread_count, 4)
      owner        = opts.fetch(:owner, nil)
      group        = opts.fetch(:group, nil)

      queue = Queue.new
      urls.map { |url| queue << url }
      threads = thread_count.times.map do
        Thread.new do
          Net::HTTP.start(server, 80) do |http|
            while !queue.empty? && url = queue.pop
              uri = URI(url)
              file = ::File.join(dstdir, ::File.basename(url))
              Chef::Log.info "Downloading from 【#{server}】#{uri}"
              request = Net::HTTP::Get.new uri.request_uri
              http.read_timeout = 500
              http.request request do |response|
                open file, 'w' do |io|
                  response.read_body do |chunk|
                    io.write chunk
                  end
                end
              end
              if owner && group
                FileUtils.chown(owner, group, file)
              elsif owner
                FileUtils.chown(owner, nil, file)
              elsif group
                FileUtils.chown(nil, group, file)
              end
              Chef::Log.info "Downloaded from 【#{server}】to #{file}"
            end
          end
        end
      end
      threads.each(&:join)
    end
    alias_method :dl_files, :remote_files

    # Safely requires a gem, if it's not installed it will be installed for you
    # and then required.
    #
    # @param [String] rubygem
    #   name of the gem to require
    #
    # @param [Hash] opts
    # @option opts [String] :gem_name
    #   name of the Gem if it differs from the required name
    # @option opts [Constant] :constant
    #   name of Class used to determine if gem is already loaded
    #
    def safe_require(rubygem, opts = {})
      gem_name = opts.fetch(:gem_name, rubygem)
      constant = opts.fetch(:constant, nil)
      proc = Proc.new do
        Chef::Log.info "installing '#{gem_name}' Ruby Gem"
        chef_gem(gem_name){action :nothing}.run_action(:install)
      end
      begin
        if constant
          require rubygem unless defined?(constant)
        else
          require rubygem
        end
      rescue LoadError
        CompileTime.new(self).evaluate(proc.call)
        require rubygem
      end
    end

    # Return the checksum of a file.
    #
    # @param [String] file
    #   file to checksum
    #
    # @return [sha]
    #
    def checksum(file)
      ::File.exists?(file) ? Chef::Digester.checksum_for_file(file) : nil
    end

    # A sorta thread-safe list, nothing too hardcore but good enough. Or as the
    # kids say now Minimum Viable Product (MVP), as we adults know it as, shit.
    # So yes, I'm saying it's a shitty list, but that's all that I need for this
    # shitty task. ;-)
    #
    class List
      def initialize
        @mutex = Mutex.new
        @condition = Condition.new
        @list = []
      end

      def size
        @mutex.synchronize { @list.size }
      end
      alias_method :length, :size

      def empty?
        @mutex.synchronize { @list.empty? }
      end

      def <<(value)
        @mutex.synchronize do
          @list << value
          @condition.signal
        end
      end

      def delete(value)
        @mutex.synchronize { @list.delete(value) }
      end

      def take
        @mutex.synchronize do
          @condition.wait(@mutex) while @list.empty?
          @list.shift
        end
      end
    end

    class Event
      # Creates a new Event in the unset state. Threads calling #wait on the
      # Event will block.
      #
      def initialize
        @set = false
        @mutex = Mutex.new
        @condition = Condition.new
      end

      # Is the object in the set state?
      #
      # @return [Boolean]
      #   indicating whether or not the Event has been set
      #
      def set?
        @mutex.lock
        @set
      ensure
        @mutex.unlock
      end

      # Trigger the event, setting the state to set and releasing all threads
      # waiting on the event. Has no effect if the Event has already been set.
      #
      # @return [Boolean]
      #   should always return true, if not call the fire department
      #
      def set
        @mutex.lock
        unless @set
          @set = true
          @condition.broadcast
        end
        true
      ensure
        @mutex.unlock
      end

      def try?
        @mutex.lock
        if @set
          false
        else
          @set = true
          @condition.broadcast
          true
        end
      ensure
        @mutex.unlock
      end

      # Reset a previously set event back to the unset state. Has no effect if
      # the Event has not yet been set.
      #
      # @return [Boolean]
      #   should always return true, if not call in the hazmat team
      #
      def reset
        @mutex.lock
        @set = false
        true
      ensure
        @mutex.unlock
      end

      # Wait a given number of seconds for the Event to be set by another
      # thread. Will wait forever when no timeout value is given. Returns
      # immediately if the Event has already been set.
      #
      # @return [Boolean]
      #   true if the Event was set before timeout else false
      #
      def wait(timeout = nil)
        @mutex.lock
        unless @set
          remaining = Condition::Result.new(timeout)
          while !@set && remaining.can_wait?
            remaining = @condition.wait(@mutex, remaining.remaining_time)
          end
        end
        @set
      ensure
        @mutex.unlock
      end
    end

    class Condition
      class Result
        attr_reader :remaining_time

        def initialize(remaining_time)
          @remaining_time = remaining_time
        end

        # @return [Boolean]
        #   true if thread has been waken up by a #signal or a #broadcast call
        #
        def woken_up?
          @remaining_time.nil? || @remaining_time > 0
        end
        alias_method :can_wait?, :woken_up?

        # @return [Boolean]
        #   true if current thread has been waken up due to a timeout
        #
        def timed_out?
          @remaining_time != nil && @remaining_time <= 0
        end
      end

      def initialize
        @condition = ConditionVariable.new
      end

      # @param [Mutex] mutex
      #   the locked mutex guarding the wait
      # @param [Object] timeout
      #   nil means no timeout
      #
      # @return [Result]
      #
      def wait(mutex, timeout = nil)
        start_time = Time.now.to_f
        @condition.wait(mutex, timeout)
        if timeout.nil?
          Result.new(nil)
        else
          Result.new(start_time + timeout - Time.now.to_f)
        end
      end

      # Wakes up a waiting thread
      #
      # @return [true]
      #
      def signal
        @condition.signal
        true
      end

      # Wakes up all waiting threads
      #
      # @return [true]
      #
      def broadcast
        @condition.broadcast
        true
      end
    end

    class CompileTime
      def initialize(recipe)
        @recipe = recipe
      end

      def evaluate(&block)
        instance_eval(&block)
      end

      def method_missing(method, *args, &block)
        resource = @recipe.send(mmethod, *args, &block)
        if resource.is_a?(Chef::Resource)
          actions  = Array(resource.action)
          resource.action(:nothing)

          actions.each do |action|
            resource.run_action(action)
          end
        end
        resource
      end
    end
  end

  unless Chef::Recipe.ancestors.include?(Garcon::Helpers)
    Chef::Recipe.send(:include, Garcon::Helpers)
    Chef::Resource.send(:include, Garcon::Helpers)
    Chef::Provider.send(:include, Garcon::Helpers)
  end
end
