# encoding: UTF-8

include_recipe 'chef_handler'

reporter = ::File.join(node[:chef_handler][:handler_path], 'devreporter.rb')

cookbook_file reporter do
  mode 00600
  action :create
end

chef_handler 'DevReporter' do
  source reporter
  supports report: true
  action :enable
end
