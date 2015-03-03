# encoding: UTF-8
#
# Cookbook Name:: garcon
# Recipe:: civilize
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

node[:garcon][:civilize][:docker].each do |pkg|
  package pkg do
    only_if { docker? }
    action :install
  end
end

node[:garcon][:civilize][:rhel_svcs].each do |svc|
  service svc do
    action [:stop, :disable]
  end
end

execute 'iptables -F' do
  ignore_failure true
  only_if { node[:garcon][:civilize][:iptables] }
  action   :run
end

execute 'setenforce 0' do
  ignore_failure true
  only_if { node[:garcon][:civilize][:selinux] && selinux? }
  action   :run
end

cookbook_file '/root/.bashrc' do
  source   'bashrc'
  owner    'root'
  group    'root'
  mode      00644
  only_if { node[:garcon][:civilize][:dotfiles] }
  action   :create
end

cookbook_file '/root/.inputrc' do
  source   'inputrc'
  owner    'root'
  group    'root'
  mode      00644
  only_if { node[:garcon][:civilize][:dotfiles] }
  action   :create
end

%w[/tmp /var/tmp].each do |dir|
  house_keeping dir do
    recursive true
    exclude   %r(/^ssh-*/i)
    age       15
    size     '10M'
    action   :purge
  end
end
