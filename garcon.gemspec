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

require_relative 'files/lib/garcon/version'

Gem::Specification.new do |gem|
  gem.name        =   'garcon'
  gem.version     =    Garcon::VERSION.dup
  gem.authors     = [ 'Stefano Harding' ]
  gem.email       = [ 'riddopic@gmail.com' ]
  gem.description =   'A useful collection of methods to make cooking more fun'
  gem.summary     =    gem.description
  gem.homepage    =   'https://github.com/riddopic/garcon'
  gem.license     =   'Apache 2.0'

  gem.require_paths    = [ 'lib' ]
  gem.files            = `git ls-files`.split("\n")
  gem.test_files       = `git ls-files -- {spec}/*`.split("\n")
  gem.extra_rdoc_files = %w[LICENSE.md README.md]

  gem.add_dependency('chef',     '>= 11.8.0')
  gem.add_dependency('hitimes')

  gem.add_development_dependency('yard')
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('rake')
  gem.add_development_dependency('rubocop')
  gem.add_development_dependency('geminabox-rake')

  # Development gems
  gem.add_dependency('addressable', '~> 2.3')
  gem.add_dependency('rake',       '~> 10.4')
  gem.add_dependency('yard',        '~> 0.8')
  gem.add_dependency('pry')

  # Test gems
  gem.add_dependency('rspec',      '~> 3.2')
  gem.add_dependency('rspec-its',  '~> 1.2')
  gem.add_dependency('chefspec',   '~> 4.2')
  gem.add_dependency('fuubar',     '~> 2.0')
  gem.add_dependency('simplecov',  '~> 0.9')
  gem.add_dependency('foodcritic', '~> 4.0')

  # Integration gems
  gem.add_dependency('test-kitchen', '~> 1.3')
  gem.add_dependency('kitchen-vagrant')
  gem.add_dependency('vagrant-wrapper')
  gem.add_dependency('kitchen-docker')
  gem.add_dependency('kitchen-sync')
  gem.add_dependency('berkshelf', '~> 3.2')
end
