# encoding: UTF-8
#
# Cookbook Name:: garcon
# Handler:: threadpool
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

require 'chef/handler'

class ThreadPool < Chef::Handler
  attr_accessor :pool

  def initialize(pool)
    @pool = pool
    Chef::Log.debug "#{self.class.to_s} initialized."
  end

  def report
    @pool.wait_done
    Chef::Log.debug "Thread-pool shutdown..."
  ensure
    @pool.shutdown
  end
end
