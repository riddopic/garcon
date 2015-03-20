# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: helpers
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

# Helper methods for cookbook.
#
module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Interpolation
    include Garcon::Exceptions

    # Provides recursive interpolation of node objects, basically standard
    # string interpolation.
    #
    # @example
    #
    # @return [String, Mash]
    def expand_on(item, parent = nil)
      item = expand item, parent
      item.is_a?(Hash) ? ::Mash.new(item) : item
    end

    private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def sym(key)
      key.respond_to?(:to_sym) ? key.to_sym : key
    end

    def expand(item, parent = nil)
      item = item.to_hash if item.respond_to? :to_hash
      if item.is_a? Hash
        item = item.inject({}) { |memo, (k,v)| memo[sym(k)] = v; memo }
        item.inject({}) { |memo, (k,v)| memo[sym(k)] = expand(v, item); memo }
      elsif item.is_a? Array
        item.map { |i| expand(i, parent) }
      elsif item.is_a? String
        item % parent rescue item
      else
        item
      end
    end
  end

  unless Chef::Recipe.ancestors.include?(Garcon::Interpolation)
    Chef::Recipe.send(:include,   Garcon::Interpolation)
    Chef::Resource.send(:include, Garcon::Interpolation)
    Chef::Provider.send(:include, Garcon::Interpolation)
  end
end
