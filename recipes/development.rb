# encoding: UTF-8
#
# Cookbook Name:: garcon
# Recipe:: development
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

#  T H I S   R E C I P E   I S   F O R   D E V E L O P M E N T   O N L Y !

include_recipe 'chef_handler'

reporter = ::File.join(node[:chef_handler][:handler_path], 'devreporter.rb')

cookbook_file reporter do
  owner  'root'
  group  'root'
  mode    00600
  action :create
end

chef_handler 'DevReporter' do
  source   reporter
  supports report: true
  action  :enable
end

if node[:garcon][:civilize][:ruby] && !defined?(Pry)
  chef_gem 'pry'
  Chef::Recipe.send(:require, 'pry')
end

if node[:garcon][:civilize][:ruby] && !defined?(AwesomePrint)
  chef_gem 'awesome_print'
  Chef::Recipe.send(:require, 'ap')
end
