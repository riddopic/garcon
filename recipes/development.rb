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

# For cookbook development only...
chef_gem('hoodie')        { action :nothing }.run_action(:install)
chef_gem('awesome_print') { action :nothing }.run_action(:install)
chef_gem('pry')           { action :nothing }.run_action(:install)

require 'hoodie'         unless defined?(Hoodie)
require 'hoodie/logging' unless defined?(Hoodie::Logging)
require 'pry'
require 'ap'

Chef::Recipe.send(:include,   Hoodie::Logging)
Chef::Resource.send(:include, Hoodie::Logging)
Chef::Provider.send(:include, Hoodie::Logging)

Hoodie.config { |c| c.logging = true }
