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

module Garcon
  class InvalidStateError              < StandardError; end
  class InvalidTransitionError         < StandardError; end
  class InvalidCallbackError           < StandardError; end
  class GuardFailedError               < StandardError; end
  class TransitionFailedError          < StandardError; end
  class UnserializedMetadataError      < StandardError; end
  class IncompatibleSerializationError < StandardError; end
  class TransitionConflictError        < StandardError; end

  def self.configure(&block)
    config           = Config.new(block)
    @storage_adapter = config.adapter_class
  end

  def self.storage_adapter
    @storage_adapter || Adapters::Memory
  end

  module Adapters
    class Memory
      attr_reader :transition_class
      attr_reader :history
      attr_reader :parent_model

      # We only accept mode as a parameter to maintain a consistent interface
      # with other adapters which require it.
      def initialize(transition_class, parent_model, observer, _ = {})
        @history          = []
        @transition_class = transition_class
        @parent_model     = parent_model
        @observer         = observer
      end

      def create(from, to, metadata = {})
        from       = from.to_s
        to         = to.to_s
        transition = transition_class.new(to, next_sort_key, metadata)

        @observer.execute(:before, from, to, transition)
        @history << transition
        @observer.execute(:after, from, to, transition)
        @observer.execute(:after_commit, from, to, transition)
        transition
      end

      def last
        @history.sort_by(&:sort_key).last
      end

      private

      def next_sort_key
        (last && last.sort_key + 10) || 0
      end
    end

    class MemoryTransition
      attr_accessor :created_at
      attr_accessor :updated_at
      attr_accessor :to_state
      attr_accessor :sort_key
      attr_accessor :metadata

      def initialize(to, sort_key, metadata = {})
        @created_at = Time.now
        @updated_at = Time.now
        @to_state   = to
        @sort_key   = sort_key
        @metadata   = metadata
      end
    end
  end

  module Machine
    def self.included(base)
      base.extend(ClassMethods)
      base.send(:attr_reader, :object)
    end

    # Retry any transitions that fail due to a TransitionConflictError
    def self.retry_conflicts(max_retries = 1)
      retry_attempt = 0

      begin
        yield
      rescue TransitionConflictError
        retry_attempt += 1
        retry_attempt <= max_retries ? retry : raise
      end
    end

    module ClassMethods
      attr_reader :initial_state

      def states
        @states ||= []
      end

      def events
        @events ||= {}
      end

      def state(name, options = { initial: false })
        name = name.to_s
        if options[:initial]
          validate_initial_state(name)
          @initial_state = name
        end
        states << name
      end

      def event(name, &block)
        EventTransitions.new(self, name, &block)
      end

      def successors
        @successors ||= {}
      end

      def callbacks
        @callbacks ||= {
          before:       [],
          after:        [],
          after_commit: [],
          guards:       []
        }
      end

      def transition(options = { from: nil, to: nil }, event = nil)
        from = to_s_or_nil(options[:from])
        to   = array_to_s_or_nil(options[:to])

        raise InvalidStateError, "No to states provided." if to.empty?

        successors[from] ||= []

        ([from] + to).each { |state| validate_state(state) }

        successors[from] += to

        if event
          events[event]       ||= {}
          events[event][from] ||= []
          events[event][from]  += to
        end
      end

      def before_transition(options = { from: nil, to: nil }, &block)
        add_callback(
          options.merge(callback_class: Callback, callback_type: :before),
          &block)
      end

      def guard_transition(options = { from: nil, to: nil }, &block)
        add_callback(
          options.merge(callback_class: Guard, callback_type: :guards),
          &block)
      end

      def after_transition(options = { from: nil, to: nil,
                                       after_commit: false }, &block)
        callback_type = options[:after_commit] ? :after_commit : :after

        add_callback(
          options.merge(callback_class: Callback, callback_type: callback_type),
          &block)
      end

      def validate_callback_condition(options = { from: nil, to: nil })
        from = to_s_or_nil(options[:from])
        to   = array_to_s_or_nil(options[:to])

        ([from] + to).compact.each { |state| validate_state(state) }
        return if from.nil? && to.empty?

        validate_not_from_terminal_state(from)
        to.each { |state| validate_not_to_initial_state(state) }

        return if from.nil? || to.empty?

        to.each { |state| validate_from_and_to_state(from, state) }
      end

      # Check that the 'from' state is not terminal
      def validate_not_from_terminal_state(from)
        unless from.nil? || successors.keys.include?(from)
          raise InvalidTransitionError,
                "Cannot transition away from terminal state '#{from}'"
        end
      end

      # Check that the 'to' state is not initial
      def validate_not_to_initial_state(to)
        unless to.nil? || successors.values.flatten.include?(to)
          raise InvalidTransitionError,
                "Cannot transition to initial state '#{to}'"
        end
      end

      # Check that the transition is valid when 'from' and 'to' are given
      def validate_from_and_to_state(from, to)
        unless successors.fetch(from, []).include?(to)
          raise InvalidTransitionError,
                "Cannot transition from '#{from}' to '#{to}'"
        end
      end

      private

      def add_callback(options, &block)
        from           = to_s_or_nil(options[:from])
        to             = array_to_s_or_nil(options[:to])
        callback_klass = options.fetch(:callback_class)
        callback_type  = options.fetch(:callback_type)

        validate_callback_condition(from: from, to: to)
        callbacks[callback_type] <<
          callback_klass.new(from: from, to: to, callback: block)
      end

      def validate_state(state)
        unless states.include?(state.to_s)
          raise InvalidStateError, "Invalid state '#{state}'"
        end
      end

      def validate_initial_state(state)
        unless initial_state.nil?
          raise InvalidStateError, "Cannot set initial state to '#{state}', " \
                                   "already defined as #{initial_state}."
        end
      end

      def to_s_or_nil(input)
        input.nil? ? input : input.to_s
      end

      def array_to_s_or_nil(input)
        Array(input).map { |item| to_s_or_nil(item) }
      end
    end

    def initialize(object, options = {
                        transition_class: Garcon::Adapters::MemoryTransition })
      @object = object
      @transition_class = options[:transition_class]
      @storage_adapter  = adapter_class(@transition_class).new(
        @transition_class, object, self, options)
      send(:after_initialize) if respond_to? :after_initialize
    end

    def current_state
      last_action = last_transition
      last_action ? last_action.to_state : self.class.initial_state
    end

    def allowed_transitions
      successors_for(current_state).select { |state| can_transition_to?(state) }
    end

    def last_transition
      @storage_adapter.last
    end

    def can_transition_to?(new_state, metadata = {})
      validate_transition(from:     current_state,
                          to:       new_state,
                          metadata: metadata)
      true
    rescue TransitionFailedError, GuardFailedError
      false
    end

    def history
      @storage_adapter.history
    end

    def transition_to!(new_state, metadata = {})
      initial_state = current_state
      new_state     = new_state.to_s

      validate_transition(from:     initial_state,
                          to:       new_state,
                          metadata: metadata)

      @storage_adapter.create(initial_state, new_state, metadata)

      true
    end

    def trigger!(event_name, metadata = {})
      transitions = self.class.events.fetch(event_name) do
        raise Garcon::TransitionFailedError, "Event #{event_name} not found"
      end

      new_state = transitions.fetch(current_state) do
        raise Garcon::TransitionFailedError,
              "State #{current_state} not found for Event #{event_name}"
      end

      transition_to!(new_state.first, metadata)
      true
    end

    def execute(phase, initial_state, new_state, transition)
      callbacks = callbacks_for(phase, from: initial_state, to: new_state)
      callbacks.each { |cb| cb.call(@object, transition) }
    end

    def transition_to(new_state, metadata = {})
      self.transition_to!(new_state, metadata)
    rescue TransitionFailedError, GuardFailedError
      false
    end

    def trigger(event_name, metadata = {})
      self.trigger!(event_name, metadata)
    rescue TransitionFailedError, GuardFailedError
      false
    end

    def available_events
      state = current_state
      self.class.events.select { |_, t| t.key?(state) }.map(&:first)
    end

    private

    def adapter_class(transition_class)
      if transition_class == Garcon::Adapters::MemoryTransition
        Adapters::Memory
      else
        Garcon.storage_adapter
      end
    end

    def successors_for(from)
      self.class.successors[from] || []
    end

    def guards_for(options = { from: nil, to: nil })
      select_callbacks_for(self.class.callbacks[:guards], options)
    end

    def callbacks_for(phase, options = { from: nil, to: nil })
      select_callbacks_for(self.class.callbacks[phase], options)
    end

    def select_callbacks_for(callbacks, options = { from: nil, to: nil })
      from = to_s_or_nil(options[:from])
      to   = to_s_or_nil(options[:to])
      callbacks.select { |callback| callback.applies_to?(from: from, to: to) }
    end

    def validate_transition(options = { from: nil, to: nil, metadata: nil })
      from = to_s_or_nil(options[:from])
      to   = to_s_or_nil(options[:to])

      successors = self.class.successors[from] || []
      unless successors.include?(to)
        raise TransitionFailedError,
              "Cannot transition from '#{from}' to '#{to}'"
      end

      # Call all guards, they raise exceptions if they fail
      guards_for(from: from, to: to).each do |guard|
        guard.call(@object, last_transition, options[:metadata])
      end
    end

    def to_s_or_nil(input)
      input.nil? ? input : input.to_s
    end
  end

  class Callback
    attr_reader :from
    attr_reader :to
    attr_reader :callback

    def initialize(options = { from: nil, to: nil, callback: nil })
      unless options[:callback].respond_to?(:call)
        raise InvalidCallbackError, "No callback passed"
      end

      @from     = options[:from]
      @to       = Array(options[:to])
      @callback = options[:callback]
    end

    def call(*args)
      callback.call(*args)
    end

    def applies_to?(options = { from: nil, to: nil })
      matches(options[:from], options[:to])
    end

    private

    def matches(from, to)
      matches_all_transitions         ||
        matches_to_state(from, to)    ||
        matches_from_state(from, to)  ||
        matches_both_states(from, to)
    end

    def matches_all_transitions
      from.nil? && to.empty?
    end

    def matches_from_state(from, to)
      (from == self.from  && (to.nil? || self.to.empty?))
    end

    def matches_to_state(from, to)
      ((from.nil? || self.from.nil?) && self.to.include?(to))
    end

    def matches_both_states(from, to)
      from == self.from && self.to.include?(to)
    end
  end

  class Guard < Callback
    def call(*args)
      unless super(*args)
        raise GuardFailedError,
              "Guard on transition from: '#{from}' to '#{to}' returned false"
      end
    end
  end

  class Config
    attr_reader :adapter_class

    def initialize(block = nil)
      instance_eval(&block) unless block.nil?
    end

    def storage_adapter(adapter_class)
      @adapter_class = adapter_class
    end
  end

  class EventTransitions
    attr_reader :machine, :event_name

    def initialize(machine, event_name, &block)
      @machine    = machine
      @event_name = event_name
      instance_eval(&block)
    end

    def transition(options = { from: nil, to: nil })
      machine.transition(options, event_name)
    end
  end
end
