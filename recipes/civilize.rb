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

include_recipe 'yum-epel::default'
version = run_context.cookbook_collection[cookbook_name].metadata.version

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
  only_if { node[:garcon][:civilize][:iptables] && !docker? }
  action   :run
end

execute 'setenforce 0' do
  ignore_failure true
  only_if { node[:garcon][:civilize][:selinux] && selinux? }
  action   :run
end

template '/etc/profile.d/ps1.sh' do
  owner    'root'
  group    'root'
  mode      00644
  variables version: version
  action   :create
end

users = if node[:garcon][:civilize][:dotfiles].is_a?(TrueClass)
          Array('root')
        elsif node[:garcon][:civilize][:dotfiles].respond_to?(:to_ary)
          users = node[:garcon][:civilize][:dotfiles]
        elsif node[:garcon][:civilize][:dotfiles].respond_to?(:to_str)
          users = Array(node[:garcon][:civilize][:dotfiles])
        end

users.each do |user|
  home = user =~ /root/ ? '/root' : "/home/#{user}"

  cookbook_file "#{home}/.bashrc" do
    source   'bashrc'
    owner     user
    group     user
    mode      00644
    action   :create
  end

  cookbook_file "#{home}/.inputrc" do
    source   'inputrc'
    owner     user
    group     user
    mode      00644
    action   :create
  end
end

# %w[/tmp /var/tmp].each do |dir|
#   house_keeping dir do
#     recursive true
#     exclude   %r(/^ssh-*/i)
#     age       15
#     size     '10M'
#     action   :purge
#   end
# end
