# encoding: UTF-8

template '/etc/motd' do
  owner  'root'
  group  'root'
  mode    00644
  action :create
end

directory '/tmp/local/bin/bash/bob/baz' do
  recursive true
  action :create
end

download '/tmp/local/bin/bash/bob/baz/SQL2012STD_1_3.zip' do
  directory '/tmp/local/bin/bash/bob/baz'
  source 'http://winini.mudbox.dev/packages_3.0/SQL/SQL2012STD_1_3.zip'
end
