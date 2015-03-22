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
  owner      'root'
  group      'root'
  mode        00600
  action     :create
end

chef_handler 'DevReporter' do
  source      reporter
  arguments   data: Faker::Hacker.say_something_smart
  supports    report: true
  action     :enable
end

if node[:garcon][:civilize][:ruby] && !defined?(Pry)
  chef_gem 'pry' do
    compile_time(false) if respond_to?(:compile_time)
    notifies :create, 'ruby_block[pry]', :immediately
    action   :install
  end

  ruby_block :pry do
    block  { Chef::Recipe.send(:require, 'pry') }
    action   :create
  end
end

if node[:garcon][:civilize][:ruby] && !defined?(AwesomePrint)
  chef_gem 'awesome_print' do
    compile_time(false) if respond_to?(:compile_time)
    notifies :create, 'ruby_block[awesome_print]', :immediately
    action   :install
  end

  ruby_block :awesome_print do
    block  { Chef::Recipe.send(:require, 'ap') }
    action   :nothing
  end
end

#  T H I S   R E C I P E   I S   F O R   D E V E L O P M E N T   O N L Y !
