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

source 'https://rubygems.org'

gem 'berkshelf'
gem 'rake'
gem 'yard'
gem 'rspec'
gem 'rubocop'
gem 'foodcritic'

group :test, :integration do
  gem 'chefspec'
  gem 'test-kitchen'
  gem 'kitchen-sync'
  gem 'kitchen-vagrant'
  gem 'kitchen-docker'
  gem 'serverspec'
end

group :plugins do
  gem 'vagrant-berkshelf'
  gem 'vagrant-chef-zero'
  gem 'vagrant-omnibus'
end
