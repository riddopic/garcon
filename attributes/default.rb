# encoding: UTF-8
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

# Civilize a node into behaving properly and not being the animal it is.
default[:garcon][:civilize].tap do |civilize|
  civilize[:iptables]     = true
  civilize[:selinux]      = true
  civilize[:dotfiles]     = true
  civilize[:ruby]         = true
  civilize[:ps1_root_msg] = 'CHEF Managed'
  civilize[:ps1_usr_msg]  = 'CHEF Managed'
  civilize[:docker]       = %w[
    tar
    htop
    passwd
    initscripts
  ]
  civilize[:rhel_svcs] = %w[
    autofs
    avahi-daemon
    bluetooth
    cpuspeed
    cups
    gpm
    haldaemon
    messagebu
  ]
end

gpg = case platform_version.to_i
      when 7
        'http://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7'
      else
        'http://apt.sw.be/RPM-GPG-KEY.dag.txt'
      end
default[:garcon][:repo][:gpg] = gpg

url = case platform_version.to_i
      when 5
        'http://mirrorlist.repoforge.org/el5/mirrors-rpmforge'
      when 6, 2013, 2014
        'http://mirrorlist.repoforge.org/el6/mirrors-rpmforge'
      when 7
        'http://mirrors.fedoraproject.org/mirrorlist?repo=epel-7&arch=$basearch'
      end
default[:garcon][:repo][:url] = url
