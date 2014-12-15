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

require_relative 'garcon'

# A Chef resource for unzipping files.
#
class Chef::Resource::ZipFile < Chef::Resource::LWRPBase

  # Chef attributes
  identity_attr :source
  provides :zip_file

  # Set the resource name
  self.resource_name = :zip_file

  # Actionss
  actions :zip, :unzip
  default_action :nothing

  attribute :source,       kind_of:  String, name_attribute:true
  # unzip where zip_file is if no destination is given.
  attribute :destination,  kind_of:  String, default: lazy { |new_resource|
    ::File.dirname(new_resource.source) }
  attribute :owner,        kind_of: [String, Integer],       default: nil
  attribute :group,        kind_of: [String, Integer],       default: nil
  attribute :mode,         kind_of:  Integer,                default: nil
  attribute :remove_after, kind_of: [TrueClass, FalseClass], default: false
end
