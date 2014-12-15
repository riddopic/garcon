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

module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Helpers
    def self.included(base)
      include(ClassMethods)

      base.send(:include, ClassMethods)
    end
    private_class_method :included

    class StateMachine
      def initialize(transition_function, initial_state)
        @transition_function = transition_function
        @state = initial_state
      end

      attr_reader :state

      def send_input(input)
        @state, output = @transition_function.call(@state, input)
        output
      end
    end

    class TransitionTable
      class TransitionError < RuntimeError
        def initialize(state, input)
          super "No transition from state #{state.inspect} " \
                "for input #{input.inspect}"
        end
      end

      def initialize(transitions)
        @transitions = transitions
      end

      def call(state, input)
        @transitions.fetch([state, input])
      rescue KeyError
        raise TransitionError.new(state, input)
      end
    end

    # class SomeClass
    #   STATE_TRANSITIONS = TransitionTable.new(
    #     # State       Input      Next state            Output
    #     [:stateless, :init ] => [:initialize, :init ],
    #     [:first_run, :init ] => [:runnable,   :run  ],
    #     [:runnable,  :run  ] => [:hibernate,  :sleep],
    #     [:hibernate, :sleep] => [:wakeupcall, :sleep],
    #     [:awoken,    :clean] => [:domrmant,   :sleep]
    #   )
    # 
    #   def initialize
    #     @state_machine = StateMachine.new(STATE_TRANSITIONS, :stateless)
    #   end
    # 
    #   def handle_event(event)
    #     action = @state_machine.send_input(event)
    #     send(action) unless action.nil?
    #   end
    # 
    #   def init
    #     # do some initing...
    #   end
    # 
    #   def sleep
    #     # do some sleeping...
    #   end
    # 
    #   def clean
    #     # do a lot of clean...
    #   end
    # 
    #   def run
    #     # do a bunch of running...
    #   end
    # end
  end
end
