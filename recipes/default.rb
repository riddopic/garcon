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

observable_event(:event) do
  Chef::Log.info 'An observable event'
  ruby_block 'Inform on the observable event' do
    block do
      Chef::Log.info 'The observable event'
    end
  end
end

chef_gem('concurrent-ruby') { action :nothing }.run_action(:install)
require 'concurrent' unless defined?(Concurrent)
# Concurrent::Promise.execute { prerequisite unless installed?('aria2c') }

concurrent :one do
  block do
    recipe_block :one do
      prerequisite unless installed?('aria2c')
      sleep(900)
    end
  end
end

begin
  chef_gem('hoodie') { action :nothing }.run_action(:install)
rescue
  node.override[:'build-essential'][:compile_time] = true
  monitor.synchronize { single_include 'build-essential::default' }
  chef_gem('hoodie') { action :nothing }.run_action(:install)
end
require 'hoodie' unless defined?(Hoodie)

%w(rubyzip).each do |rubygem|
  chef_gem(rubygem) { action :nothing }.run_action(:install)
end
require 'zip' unless defined?(Zip)

ruby_block '--|--|--|-- This is before the observer --|--|--|--' do
  block do
    Chef::Log.info '--\--\--\-- Before observer --\--\--\--'
  end
end

notify_observers(:event)

ruby_block '--|--|--|-- This is after the observer --|--|--|--' do
  block do
    Chef::Log.info '--/--/--/-- After observer --/--/--/--'
  end
end

concurrent :two do
  block do
    recipe_block :two do
      %w[vim emacs httpd tomcat6 mysql postfix postgresql].each do |pkg|
        announce "Request received to install #{pkg}"
        announce "Request will be processed shortly"
        sleep rand 10
      end
      sleep(900)
    end
  end
end

ruby_block :foo do
  block do
    announce "in ruby block, hopefully not waiting on dat shit"
    announce "let's check on the lock for da fuck of it."
    announce monitor.inspect
    sleep 3
    announce "let's check on the lock for da fuck of it."
    announce monitor.inspect
    sleep 3
    announce "let's check on the lock for da fuck of it."
    announce monitor.inspect
  end
end
