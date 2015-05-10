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

#  T H I S   R E C I P E   I S   F O R   D E V E L O P M E N T   O N L Y !

include_recipe 'chef_handler::default'

reporter = ::File.join(node[:chef_handler][:handler_path], 'devreporter.rb')

cookbook_file reporter do
  owner      'root'
  group      'root'
  mode        00600
  action     :create
end

chef_handler 'DevReporter' do
  source      reporter
  supports    report: true, exception: true
  action     :enable
end

chef_gem 'pry' do
  compile_time(false) if respond_to?(:compile_time)
  not_if  { gem_installed?('pry') }
  action   :install
end

chef_gem 'awesome_print' do
  compile_time(false) if respond_to?(:compile_time)
  not_if  { gem_installed?('awesome_print') }
  action   :install
end

ruby_block :pry do
  block   { Chef::Recipe.send(:require, 'pry') }
  only_if { gem_installed?('pry') }
  action   :create
end

ruby_block :awesome_print do
  block   { Chef::Recipe.send(:require, 'ap') }
  only_if { gem_installed?('awesome_print') }
  action   :create
end

#  T H I S   R E C I P E   I S   F O R   D E V E L O P M E N T   O N L Y !
