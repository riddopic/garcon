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

# Add #blank? method to Numeric class.
class Numeric
  # Numerics are never blank
  #
  # @example
  #   0.blank?          # =>  false
  #   1.blank?          # =>  false
  #   6.54321.blank?    # =>  false
  #
  # @return [FalseClass]
  #
  # @api public
  def blank?
    false
  end

  # Since Numeric is immutable it cannot be duplicated.
  # For this reason #try_dup returns +self+.
  #
  #   1.dup!  #=> 1
  #
  def dup!   ; self  ; end
  def dup?   ; false ; end
  def clone? ; false ; end
end
