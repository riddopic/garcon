# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: exceptions
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

# Include hooks to extend Resource with class and instance methods.
#
module Garcon
  # When foo and bar collide, exceptions happen.
  #
  module Exceptions

    class UnsupportedPlatform < RuntimeError
      def initialize(platform)
        super "This functionality is not supported on platform #{platform}."
      end
    end

    class TimeoutError            < StandardError; end
    class InvalidStateError       < StandardError; end
    class InvalidTransitionError  < StandardError; end
    class InvalidCallbackError    < StandardError; end
    class TransitionFailedError   < StandardError; end
    class TransitionConflictError < StandardError; end
    class GuardFailedError        < StandardError; end
    class FileNotFound            < RuntimeError;  end
    class DirectoryNotFound       < RuntimeError;  end
    class ValidationError         < RuntimeError;  end
  end
end
