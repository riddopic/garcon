# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: resource_concurrent
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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

class Chef::Resource::Concurrent < Chef::Resource::LWRPBase

  identity_attr :name
  provides :concurrent, os: 'linux'

  self.resource_name = :concurrent

  actions :run
  default_action :run

  state_attrs :state

  attribute :name,  kind_of: [String, Symbol], name_attribute: true

  attribute :mutex, kind_of: Class, default: nil

  def block(&block)
    if block_given? && block
      @block = block
    else
      @block
    end
  end
end
