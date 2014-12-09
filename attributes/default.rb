#
# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
# Cookbook Name:: websphere
# Attributes:: default
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

# ============================ Thread Pool Defaults ============================
#
# Default minimum number of threads that will be retained in the pool.
default[:garcon][:thread_pool][:min_pool_size] = 8

# Default maximum number of threads that will be created in the pool.
default[:garcon][:thread_pool][:max_pool_size] = 120

# Default maximum number of tasks that may be added to the task queue. A value
# of zero means the queue may grow without bounnd.
default[:garcon][:thread_pool][:max_queue_size] = 0

# Default maximum number of seconds a thread in the pool may remain idle
# before being reclaimed.
default[:garcon][:thread_pool][:idletime] = 120

# The policy for handling new tasks that are received when the queue size has
# reached capacity.
default[:garcon][:thread_pool][:overflow_policy] = :abort

default[:garcon][:aria2] = [
  'http://repo.mudbox.dev/ibm/aria2-1.16.4-1.el6.rf.x86_64.rpm',
  'http://repo.mudbox.dev/ibm/nettle-2.2-1.el6.rf.x86_64.RPM'
]