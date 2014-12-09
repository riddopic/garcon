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

# A Chef resource to quickly download files.
#
class Chef::Resource::Download < Chef::Resource::LWRPBase
  include Garcon

  # Chef attributes
  identity_attr :source
  provides :download

  # Set the resource name
  self.resource_name = :download

  # Actionss
  actions :run
  default_action :run

  attribute :source,          kind_of: [String, URI::HTTP], name_attribute:true
  attribute :destination,     kind_of:  String,             required: true
  attribute :owner,           kind_of: [String, Integer]
  attribute :group,           kind_of: [String, Integer]
  attribute :mode,            kind_of:  Integer
  attribute :connections,     kind_of:  Integer,            default: 5
  attribute :max_connections, kind_of:  Integer,            default: 5
  attribute :checksum,        kind_of:  String, default: nil
end
