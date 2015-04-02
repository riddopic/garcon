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

require_relative '../exceptions'

module Garcon
  module Resource
    module Marzipan
      module ClassMethods
        def included(descendant)
          super
          descendant.extend ClassMethods
        end
      end
      extend ClassMethods
    end
  end

  module Provider
    module Marzipan
      module ClassMethods
        def included(klass)
          super
          klass.extend ClassMethods
          if klass.is_a?(Class) && klass.superclass == Chef::Provider
            klass.class_exec { include Implementation }
          end
          klass.class_exec { include Chef::DSL::Recipe }
        end
      end
      extend ClassMethods
    end
  end
end