# encoding: UTF-8

include_recipe 'garcon'
include_recipe 'garcon::development'
include_recipe 'test_fixtures::devreporter'

template '/etc/motd' do
  owner  'root'
  group  'root'
  mode    00644
  action :create
end

template '/root/.bash_profile' do
  source 'profile.erb'
  owner  'root'
  group  'root'
  mode    00644
  action :create
end
