# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: default
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

#        ____   ____  ____      __   ___   ____   __
#       /    T /    T|    \    /  ] /   \ |    \ |  T
#      Y   __jY  o  ||  D  )  /  / Y     Y|  _  Y|  |
#      |  T  ||     ||    /  /  /  |  O  ||  |  ||__j
#      |  l_ ||  _  ||    \ /   \_ |     ||  |  | __
#      |     ||  |  ||  .  Y\     |l     !|  |  ||  T
#      l___,_jl__j__jl__j\_j \____j \___/ l__j__jl__j

class Chef
  class Recipe

    def self.init
      require 'garcun'
    rescue LoadError
      g = Chef::Resource::ChefGem.new('garcun',
          Chef::RunContext.new(Chef::Node.new, {},
          Chef::EventDispatch::Dispatcher.new))
      g.compile_time(true) if respond_to?(:compile_time)
      g.run_action(:install)
      require 'garcun'
    end

    def monitor
      @monitor ||= Monitor.new
    end
  end
end

Chef::Recipe.send(:init)

Chef::Recipe.send(:include,    Garcon)
Chef::Resource.send(:include,  Garcon)
Chef::Provider.send(:include,  Garcon)
Erubis::Context.send(:include, Garcon)
