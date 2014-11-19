# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014 Stefano Harding
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

require 'chef/resource/lwrp_base' unless defined?(Chef::Resource::LWRPBase)

# A thread pool that dynamically grows and shrinks to fit the current workload.
# New threads are created as needed, existing threads are reused, and threads
# that remain idle for too long are killed and removed from the pool. These
# pools are particularly suited to applications that perform a high volume of
# short-lived tasks.
#
# On creation a CachedThreadPool has zero running threads. New threads are
# created on the pool as new operations are #post. The size of the pool will
# grow until #max_length threads are in the pool or until the number of threads
# exceeds the number of running and pending operations. When a new operation is
# post to the pool the first available idle thread will be tasked with the new
# operation.
#
# Should a thread crash for any reason the thread will immediately be removed
# from the pool. Similarly, threads which remain idle for an extended period of
# time will be killed and reclaimed. Thus these thread pools are very efficient
# at reclaiming unused resources.
#
class Chef::Resource::Thread < Chef::Resource::LWRPBase
  self.resource_name = :thread

  actions :run
  default_action :run

  attribute :thread_name,
    kind_of: String,
    name_attribute: true

  # Adds the given block to the ThreadPool for execution. This can be any valid
  # Chef resource and runs a convergence in parallel.
  #
  # @yield submits the block to the pool for execution
  #
  def block(&block)
    if block_given? && block
      @block = block
    else
      @block
    end
  end
end
