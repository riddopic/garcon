# encoding: UTF-8
#
# Cookbook Name:: garcon
# Recipe:: default
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

include_recipe 'chef_handler'

concurrent :run do
  block { Chef::Log.info 'Thread-pool startup' }
end.run_action(:start)

concurrent :prerequisite do
  block { monitor.synchronize { prerequisite } }
end

node.override[:'build-essential'][:compile_time] = true
monitor.synchronize { include_recipe 'build-essential::default' }

chef_gem('hoodie') { action :nothing }.run_action(:install)
require 'hoodie' unless defined?(Hoodie)

Chef::Recipe.send(:include,   Hoodie)
Chef::Resource.send(:include, Hoodie)
Chef::Provider.send(:include, Hoodie)
