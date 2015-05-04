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

name             'garcon'
maintainer       'Stefano Harding'
maintainer_email 'riddopic@gmail.com'
license          'Apache 2.0'
description      'A useful collection of methods to make cooking more fun.'
long_description  IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '1.1.2'

supports 'centos',      '>= 5.10'
supports 'oracle',      '>= 5.10'
supports 'redhat',      '>= 5.10'
supports 'scientific',  '>= 5.10'

depends 'chef_handler'
depends 'yum-epel'
depends 'yum'
