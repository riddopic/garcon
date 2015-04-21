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

require 'chef'
require 'yard'
require 'open-uri'

task default: 'test'

desc 'Run all tests except `kitchen`'
task test: [:yard, :rubocop, :foodcritic, :spec]

desc 'Run all tasks'
task all: [:yard, :rubocop, :foodcritic, :spec, 'kitchen:all']

desc 'Run kitchen integration tests'
task test: ['kitchen:all']

desc 'Build documentation'
task doc: [:readme, :yard]

desc 'Generate README.md from _README.md.erb'
task :readme do
  cmd = %w(knife cookbook doc -t _README.md.erb .)
  system(*cmd)
end

YARD::Config.load_plugin 'redcarpet-ext'
YARD::Rake::YardocTask.new do |t|
  t.files = ['**/*.rb', '-', 'README.md', 'CHANGELOG.md', 'LICENSE']
  t.options = ['--markup-provider=redcarpet', '--markup=markdown']
end

# rubocop style checker
require 'rubocop/rake_task'
RuboCop::RakeTask.new

# foodcritic chef lint
require 'foodcritic'
FoodCritic::Rake::LintTask.new do |t|
  t.options = { tags: ['~FC001'], fail_tags: ['any'], include: 'test/support/foodcritic/*', }
end

# chefspec unit tests
require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:chefspec) do |t|
  t.rspec_opts = '--color --format progress'
end

# test-kitchen integration tests
begin
  require 'kitchen/rake_tasks'
  Kitchen::RakeTasks.new
rescue LoadError
  task('kitchen:all') { puts 'Unable to run `test-kitchen`' }
end
