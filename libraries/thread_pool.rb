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

require 'thread'

module ThreadPool

  def self.running?
    Chef::Provider::Thread.pool.running?
  end

  def self.shutdown
    Chef::Provider::Thread.pool.shutdown
  end

  def self.shutdown?
    Chef::Provider::Thread.pool.shutdown?
  end

  def self.shuttingdown?
    Chef::Provider::Thread.pool.shuttingdown?
  end

  def self.length
    Chef::Provider::Thread.pool.length
  end

  def self.queue_length
    Chef::Provider::Thread.pool.queue_length
  end

  def self.scheduled_task_count
    Chef::Provider::Thread.pool.scheduled_task_count
  end

  def self.completed_task_count
    Chef::Provider::Thread.pool.completed_task_count
  end

  def self.schedule(&block)
    raise ArgumentError, 'no block given' unless block_given?
    Chef::Provider::Thread.pool.post { block }
  end
  self.singleton_class.send(:alias_method, :post, :schedule)

  def self.status
    Chef::Provider::Thread.pool.status
  end

  # Raised when errors occur during configuration.
  ConfigurationError = Class.new(StandardError)

  # Raised when a lifecycle method (such as stop) is called in an improper
  # sequence or when the object is in an inappropriate state.
  LifecycleError = Class.new(StandardError)

  # Raised when an object's methods are called when it has not been
  # properly initialized.
  InitializationError = Class.new(StandardError)

  # Raised when an object with a start/stop lifecycle has been started an
  # excessive number of times. Often used in conjunction with a restart
  # policy or strategy.
  MaxRestartFrequencyError = Class.new(StandardError)

  # Raised when an attempt is made to modify an immutable object
  # (such as an IVar) after its final state has been set.
  MultipleAssignmentError = Class.new(StandardError)

  # Raised by an Executor when it is unable to process a given task,
  # possibly because of a reject policy or other internal error.
  RejectedExecutionError = Class.new(StandardError)

  # Raised when an operation times out.
  TimeoutError = Class.new(StandardError)

  module Executor
    include Garcon

    # Does the task queue have a maximum size?
    # @note always returns false
    #
    # @return [Boolean]
    #   true if the task queue has a maximum size else false.
    #
    def can_overflow?
      false
    end

    # Does this executor guarantee serialization of its operations?
    # @note always returns false
    #
    # @return [Boolean]
    #   true if the executor guarantees that all operations will be post in the
    #   order they are received and no two operations may occur simultaneously.
    #
    def serialized?
      false
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Array] args
    #   zero or more arguments to be passed to the task
    # @yield the asynchronous task to perform
    #
    # @return [Boolean]
    #   true if the task is queued, false if the executor is not running
    #
    # @raise [ArgumentError]
    #   if no task is given
    #
    def post(*args, &task)
      raise ArgumentError, 'no block given' unless block_given?
      mutex.synchronize do
        if running?
          execute(*args, &task)
          true
        else
          false
        end
      end
    end

    # Submit a task to the executor for asynchronous processing.
    #
    # @param [Proc] task
    #   the asynchronous task to perform
    #
    # @return [self]
    #
    def <<(task)
      post(&task)
      self
    end

    # Is the executor running?
    #
    # @return [Boolean]
    #   true when running, false when shutting down or shutdown
    #
    def running?
      ! stop_event.set?
    end

    # Is the executor shuttingdown?
    #
    # @return [Boolean]
    #   true when not running and not shutdown
    #
    def shuttingdown?
      ! (running? || shutdown?)
    end

    # Is the executor shutdown?
    #
    # @return [Boolean]
    #   true when shutdown, false when shutting down or running
    #
    def shutdown?
      stopped_event.set?
    end

    # Begin an orderly shutdown. Tasks already in the queue will be executed,
    # but no new tasks will be accepted. Has no additional effect if the thread
    # pool is not running.
    #
    def shutdown
      mutex.synchronize do
        break unless running?
        stop_event.set
        shutdown_execution
      end
      true
    end

    # Begin an immediate shutdown. In-progress tasks will be allowed to
    # complete but enqueued tasks will be dismissed and no new tasks will be
    # accepted. Has no additional effect if the thread pool is not running.
    #
    def kill
      mutex.synchronize do
        break if shutdown?
        stop_event.set
        kill_execution
        stopped_event.set
      end
      true
    end

    # Block until executor shutdown is complete or until timeout.
    # @note does not initiate shutdown or termination. Either shutdown or
    #       kill must be called before this method (or on another thread).
    #
    # @param [Integer] timeout
    #   the maximum number of seconds to wait for shutdown to complete
    #
    # @return [Boolean]
    #   true if shutdown complete or false on timeout
    #
    def wait_for_termination(timeout = nil)
      stopped_event.wait(timeout)
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    attr_reader :mutex, :stop_event, :stopped_event

    # Initialize the executor by creating and initializing all the internal
    # synchronization objects.
    #
    def init_executor
      @mutex = Mutex.new
      @stop_event = Event.new
      @stopped_event = Event.new
    end

    def execute(*args, &task)
      raise NotImplementedError
    end

    # Callback method called when an orderly shutdown has completed. The
    # default behavior is to signal all waiting threads.
    #
    def shutdown_execution
      stopped_event.set
    end

    # Callback method called when the executor has been killed. The default
    # behavior is to do nothing.
    #
    def kill_execution
      # nada más
    end
  end

  class ThreadPoolWorker
    include Garcon

    # @!visibility private
    def initialize(queue, parent)
      @queue = queue
      @parent = parent
      @mutex = Mutex.new
      @last_activity = Time.now.to_f
    end

    # @!visibility private
    def dead?
      @mutex.synchronize { @thread.nil? ? false : ! @thread.alive? }
    end

    # @!visibility private
    def last_activity
      @mutex.synchronize { @last_activity }
    end

    def status
      @mutex.synchronize { @thread.nil? ? 'not running' : @thread.status }
    end

    # @!visibility private
    def kill
      @mutex.synchronize do
        Thread.kill(@thread) unless @thread.nil?
        @thread = nil
      end
    end

    # @!visibility private
    def run(thread = Thread.current)
      @mutex.synchronize do
        raise StandardError, 'already running' unless @thread.nil?
        @thread = thread
      end

      loop do
        task = @queue.pop
        if task == :stop
          @thread = nil
          @parent.on_worker_exit(self)
          break
        end

        begin
          task.last.call(*task.first)
        rescue => ex
          # let it fail
          log DEBUG, ex
        ensure
          @last_activity = Time.now.to_f
          @parent.on_end_task
        end
      end
    end
  end

  class ThreadPoolExecutor
    include Executor

    # Default maximum number of threads that will be created in the pool.
    DEFAULT_MAX_POOL_SIZE      = 2**15 # 32768

    # Default minimum number of threads that will be retained in the pool.
    DEFAULT_MIN_POOL_SIZE      = 8

    # Default maximum number of tasks that may be added to the task queue.
    DEFAULT_MAX_QUEUE_SIZE     = 0

    # Default maximum number of seconds a thread in the pool may remain idle
    # before being reclaimed.
    DEFAULT_THREAD_IDLETIMEOUT = 60

    # The set of possible overflow policies that may be set at thread pool
    # creation.
    OVERFLOW_POLICIES          = [:abort, :discard, :caller_runs]

    # The maximum number of threads that may be created in the pool.
    attr_reader :max_length

    # The minimum number of threads that may be retained in the pool.
    attr_reader :min_length

    # The largest number of threads that have been created in the pool since
    # construction.
    attr_reader :largest_length

    # The number of tasks that have been scheduled for execution on the pool
    # since construction.
    attr_reader :scheduled_task_count

    # The number of tasks that have been completed by the pool since
    # construction.
    attr_reader :completed_task_count

    # The number of seconds that a thread may be idle before being reclaimed.
    attr_reader :idletime

    # The maximum number of tasks that may be waiting in the work queue at any
    # one time. When the queue size reaches max_queue subsequent tasks will
    # be rejected in accordance with the configured overflow_policy.
    attr_reader :max_queue

    # The policy defining how rejected tasks (tasks received once the queue size
    # reaches the configured max_queue) are handled. Must be one of the values
    # specified in OVERFLOW_POLICIES.
    attr_reader :overflow_policy

    # Create a new thread pool.
    #
    # @param [Hash] opts the options which configure the thread pool
    # @option opts [Integer] :max_threads (DEFAULT_MAX_POOL_SIZE)
    #   the maximum number of threads to be created
    # @option opts [Integer] :min_threads (DEFAULT_MIN_POOL_SIZE)
    #   the minimum number of threads to be retained
    # @option opts [Integer] :idletime (DEFAULT_THREAD_IDLETIMEOUT) the maximum
    #   number of seconds a thread may be idle before being reclaimed
    # @option opts [Integer] :max_queue (DEFAULT_MAX_QUEUE_SIZE)
    #   the maximum number of tasks allowed in the work queue at any one time;
    #   a value of zero means the queue may grow without bounnd
    # @option opts [Symbol] :overflow_policy (:abort)
    #   the policy for handling new tasks that are received when the queue size
    #   has reached max_queue
    #
    # @raise [ArgumentError]
    #   if :max_threads is less than one
    # @raise [ArgumentError]
    #   if :min_threads is less than zero
    # @raise [ArgumentError]
    #   if :overflow_policy is not a value specified in OVERFLOW_POLICIES
    #
    def initialize(opts = {})
      @min_length      = opts.fetch(:min_threads, DEFAULT_MIN_POOL_SIZE).to_i
      @max_length      = opts.fetch(:max_threads, DEFAULT_MAX_POOL_SIZE).to_i
      @idletime        = opts.fetch(:idletime, DEFAULT_THREAD_IDLETIMEOUT).to_i
      @max_queue       = opts.fetch(:max_queue, DEFAULT_MAX_QUEUE_SIZE).to_i
      @overflow_policy = opts.fetch(:overflow_policy, :abort)

      if @max_length <= 0
        raise ArgumentError, 'max_threads must be greater than zero'
      end
      if @min_length < 0
        raise ArgumentError, 'min_threads cannot be less than zero'
      end
      unless OVERFLOW_POLICIES.include?(@overflow_policy)
        raise ArgumentError, "#{@overflow_policy} is not a valid policy"
      end
      if min_length > max_length
        raise ArgumentError, 'min_threads cannot be more than max_threads'
      end

      init_executor

      @pool                 = []
      @queue                = Queue.new
      @scheduled_task_count = 0
      @completed_task_count = 0
      @largest_length       = 0

      @gc_interval  = opts.fetch(:gc_interval, 1).to_i # undocumented
      @last_gc_time = Time.now.to_f - [1.0, (@gc_interval * 2.0)].max
    end

    def can_overflow?
      @max_queue != 0
    end

    # Returns an array with the status of each thread in the pool
    #
    def status
      mutex.synchronize { @pool.collect { |worker| worker.status } }
    end

    # The number of threads currently in the pool.
    #
    # @return [Integer]
    #   the length
    #
    def length
      mutex.synchronize { running? ? @pool.length : 0 }
    end

    # The number of tasks in the queue awaiting execution.
    #
    # @return [Integer]
    #  the queue_length
    #
    def queue_length
      mutex.synchronize { running? ? @queue.length : 0 }
    end

    # Number of tasks that may be enqueued before reaching max_queue and
    # rejecting new tasks. A value of -1 indicates that the queue may grow
    # without bound.
    #
    # @return [Integer]
    #   the remaining_capacity
    #
    def remaining_capacity
      mutex.synchronize { @max_queue == 0 ? -1 : @max_queue - @queue.length }
    end

    # Run on task completion.
    #
    # @!visibility private
    def on_end_task
      mutex.synchronize do
        @completed_task_count += 1 #if success
        break unless running?
      end
    end

    # Run when a thread worker exits.
    #
    # @!visibility private
    def on_worker_exit(worker)
      mutex.synchronize do
        @pool.delete(worker)
        if @pool.empty? && !running?
          stop_event.set
          stopped_event.set
        end
      end
    end

    protected #      A T T E N Z I O N E   A R E A   P R O T E T T A

    # @!visibility private
    def execute(*args, &task)
      prune_pool
      if ensure_capacity?
        @scheduled_task_count += 1
        @queue << [args, task]
      else
        if @max_queue != 0 && @queue.length >= @max_queue
          handle_overflow(*args, &task)
        end
      end
    end

    # @!visibility private
    def shutdown_execution
      if @pool.empty?
        stopped_event.set
      else
        @pool.length.times { @queue << :stop }
      end
    end

    # @!visibility private
    def kill_execution
      @queue.clear
      drain_pool
    end

    # Check the thread pool configuration and determine if the pool
    # has enought capacity to handle the request. Will grow the size
    # of the pool if necessary.
    #
    # @return [Boolean]
    #   true if the pool has enough capacity
    #
    # @!visibility private
    def ensure_capacity?
      additional = 0
      capacity   = true

      if @pool.size < @min_length
        additional = @min_length - @pool.size
      elsif @queue.empty? && @queue.num_waiting >= 1
        additional = 0
      elsif @pool.size == 0 && @min_length == 0
        additional = 1
      elsif @pool.size < @max_length || @max_length == 0
        additional = 1
      elsif @max_queue == 0 || @queue.size < @max_queue
        additional = 0
      else
        capacity = false
      end

      additional.times do
        @pool << create_worker_thread
      end

      if additional > 0
        @largest_length = [@largest_length, @pool.length].max
      end
      capacity
    end

    # Handler which executes the overflow_policy once the queue size reaches
    # max_queue.
    #
    # @param [Array] args
    #   the arguments to the task which is being handled.
    #
    # @!visibility private
    def handle_overflow(*args)
      case @overflow_policy
      when :abort
        raise RejectedExecutionError
      when :discard
        false
      when :caller_runs
        begin
          yield(*args)
        rescue => ex
          # let it fail
          log DEBUG, ex
        end
        true
      end
    end

    # Scan all threads in the pool and reclaim any that are dead or have been
    # idle too long. Will check the last time the pool was pruned and only run
    # if the configured garbage collection interval has passed.
    #
    # @!visibility private
    def prune_pool
      if Time.now.to_f - @gc_interval >= @last_gc_time
        @pool.delete_if { |worker| worker.dead? }
        # send :stop for each thread over idletime
        @pool.select { |worker|
          @idletime != 0 && Time.now.to_f - @idletime > worker.last_activity
        }.each { @queue << :stop }
        @last_gc_time = Time.now.to_f
      end
    end

    # Reclaim all threads in the pool.
    #
    # @!visibility private
    def drain_pool
      @pool.each { |worker| worker.kill }
      @pool.clear
    end

    # Create a single worker thread to be added to the pool.
    #
    # @return [Thread]
    #   the new thread.
    #
    # @!visibility private
    def create_worker_thread
      wrkr = ThreadPoolWorker.new(@queue, self)
      Thread.new(wrkr, self) do |worker, parent|
        Thread.current.abort_on_exception = false
        worker.run
        parent.on_worker_exit(worker)
      end
      wrkr
    end
  end
end
