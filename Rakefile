# encoding: UTF-8

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
