# encoding: UTF-8

template '/etc/motd' do
  owner  'root'
  group  'root'
  mode    00644
  action :create
end
