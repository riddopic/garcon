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

require_relative '../files/lib/garcon'

module Garcon
  # Cryptor for this session.
  Garcon.crypto.password = SecureRandom.base64(18)
  Garcon.crypto.salt     = Crypto.salted_hash(Garcon.crypto.password)[:salt]

  def monitor
    @monitor ||= Monitor.new
  end
end

# Cache the node object for profit and gross revenue margins.
#
class Chef::Resource::NodeCache < Chef::Resource
  include Garcon(blender: true)
  attribute(:name,  kind_of: String, name_attribute: true)
  attribute(:cache, kinf_of: Hash,   default: lazy { node })
  action(:run) do
    Garcon.config.stash.load(node: new_resource.node)
  end
end

Chef::Recipe.send(:include,   Garcon)
Chef::Resource.send(:include, Garcon)
Chef::Provider.send(:include, Garcon)

