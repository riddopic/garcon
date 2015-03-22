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

require_relative '../constraints'

class Array
  # Get or set state of object. You can think of #object_state as an in-code
  # form of marshalling.
  #
  def object_state(data=nil)
    data ? replace(data) : dup
  end

  # Treat an array of objects as version constraints.
  #
  # @example
  #   Using pure Array<String> objects like constraints
  #   ['> 2.0.0', '< 3.0.0'].satisfied_by?('2.1.0')
  #
  # @param [String] version
  #   the version to check if it is satisfied
  #
  # @return [Boolean]
  #
  # @api public
  def satisfied_by?(version)
    Garcon::Constraints::Constraint.new(*dup).satisfied_by?(version)
  end unless method_defined?(:satisfied_by?)
end
