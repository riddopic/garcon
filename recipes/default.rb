# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
# Cookbook Name:: garcon
# Recipe:: default
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

chef_gem 'concurrent-ruby'
require 'concurrent'

begin
  chef_gem('hoodie') { action :nothing }.run_action(:install)
rescue
  node.override[:'build-essential'][:compile_time] = true
  single_include 'build-essential::default'
  chef_gem('hoodie') { action :nothing }.run_action(:install)
end
require 'hoodie' unless defined?(Hoodie)
