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

# Helper methods for cookbook.
#
module Garcon
  # Returns the version of the cookbook in the current run list.
  #
  # @param [String] cookbook
  #   name to retrieve version on
  #
  # @return [Integer]
  #   version of cookbook from metadata
  #
  def cookbook_version(cookbook)
    node.run_context.cookbook_collection[cookbook].metadata.version
  end

  # Check to see if the recipe has already been included, if not include it.
  # It will return false if it has already been run or return the last value of
  # the includeed recipe.
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

  # Runs the recipe in it's own thread. NOTE: You need to ensure that the recipe
  # is thread safe and non-blocking.
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
  # since we don’t have to setup connection for each download. Also, we spin up
  # some threads to bring concurrency. There will be a lot of network I/O in
  # these threads which does not lock GIL in Ruby.
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
  # kids say now Minimum Viable Product (MVP), as we adults know it as, shit. So
  # yes, I'm saying it's a shitty list, but that's all that I need for this
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

    # Wait a given number of seconds for the Event to be set by another thread.
    # Will wait forever when no timeout value is given. Returns immediately if
    # the Event has already been set.
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

  # Deep merge value into node using output path. If the value provided is
  # nil then perform operation.
  #
  # @param [Object] element
  #   the node or mash into which the results will be deep merged
  # @param [Object] output_path
  #   the path on the node on which to deep merge the results
  # @param [Object] value
  #   the value to merge
  #
  def deep_merge(element, output_path, value)
    if value
      existing = output_path.nil? ? element :
        output_path.split('.').reduce(element.respond_to?(:override) ?
          element.override : element) { |elm, k| element.nil? ? nil : elm[k] }
      if existing
        results = ::Chef::Mixin::DeepMerge.deep_merge(value, existing).to_hash
      else
        results = value.dup
      end
      set_attribute(element, output_path, results)
    end
  end

  # Ensure attribute is present.
  #
  # @param [Object] element
  #   the root element used to base lookup on
  # @param [String, Symbol] key
  #   the path to lookup
  # @param [Object] type
  #   the expected type of the value, Set to nil to ignore type checking.
  # @param [Object] prefix
  #   the prefix already traversed to get to root
  #
  def ensure_attribute(element, key, type = nil, prefix = nil)
    value = get_attribute(element, key, type, prefix)
    label = prefix ? "#{prefix}.#{key}" : key
    raise "Attribute '#{label}' is missing" if value.nil?
    value
  end

  # Get attribute if present.
  #
  # @param [Object] element
  #   the root element used to base lookup on
  # @param [String, Symbol] key
  #   the path to lookup
  # @param [Object] prefix
  #   the prefix already traversed to get to root
  #
  def get_attribute(element, key, type = nil, prefix = nil)
    key_parts = key.split('.')
    output_entry = key_parts[0...-1].reduce(element.to_hash) do |elm, k|
      elm.nil? ? nil : elm[k]
    end
    return nil unless output_entry
    value = output_entry[key_parts.last]
    return nil if value.nil?
    label = prefix ? "#{prefix}.#{key}" : key
    if type && !value.is_a?(type)
      raise "The value of attribute '#{label}' is '#{value.inspect}' and " \
            "this is not of the expected type #{type.inspect}"
    end
    value
  end


  # Set attribute value on mash using a path. If the element is a node then
  # use override priority.
  #
  # @param [Object] element
  #   the mash/node into which the results will be set
  # @param [String, Symbol] key
  #   path on the node on which to set value
  # @param [Object] value
  #   the value to set
  #
  def set_attribute(element, key, value)
    key_parts = key.nil? ? [] : key.split('.')
    base = element.respond_to?(:override) ? element.override : element
    output_entry = key_parts[0...-1].reduce(base) { |elm, k| elm[k] }
    output_entry[key_parts.last] = value
  end

  # Invoke the action block in a separate run context and if any resources are
  # modified within the sub context then mark this node as updated.
  #
  def notifying_action(key, &block)
    action key do
      # So that we can refer to these within the sub-run-context block.
      _cached_new_resource = new_resource
      _cached_current_resource = current_resource

      # Setup a sub-run-context.
      sub_run_context = @run_context.dup
      sub_run_context.resource_collection = Chef::ResourceCollection.new

      # Declare sub-resources within the sub-run-context. Since they are
      # declared here, they do not pollute the parent run-context.
      begin
        original_run_context, @run_context = @run_context, sub_run_context
        instance_eval(&block)
      ensure
        @run_context = original_run_context
      end

      # Converge the sub-run-context inside the provider action.
      # Make sure to mark the resource as updated-by-last-action if any sub-run-
      # context resources were updated (any actual actions taken against the
      # system) during the sub-run-context convergence.
      begin
        Chef::Runner.new(sub_run_context).converge
      ensure
        if sub_run_context.resource_collection.any?(&:updated?)
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end
end

class Hash
  # Searches a deeply nested datastructure for a key path, and returns the
  # associated value. If a block is provided its value will be returned if the
  # key does not exist.
  #
  class UndefinedPathError < StandardError; end
  def retrieve(*args, &block)
    args.reduce(self) do |obj, arg|
      begin
        arg = Integer(arg) if obj.is_a? Array
        obj.fetch(arg)
      rescue ArgumentError, IndexError, NoMethodError => e
        break block.call(arg) if block
        raise UndefinedPathError,
          "Could not retrieve path (#{args.join(' > ')}) at #{arg}", e.backtrace
      end
    end
  end
end

# Include the Garcon module into the main recipe DSL
Chef::Recipe.send(:include, Garcon)
Chef::Resource.send(:include, Garcon)
Chef::Provider.send(:include, Garcon)
