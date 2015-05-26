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
require 'chef/log'
require 'chef/handler'
require 'garcun'

class DevReporter < Chef::Handler

  def initialize(opts = {})
    @cookbooks = Hash.new(0)
    @recipes   = Hash.new(0)
    @resources = Hash.new(0)
  end

  def full_name(resource)
    "#{resource.resource_name}[#{resource.name}]"
  end

  def humanize(seconds)
    [[60, :seconds],
     [60, :minutes],
     [24, :hours],
     [1000, :days] ].map do |count, name|
      if seconds > 0
        seconds, n = seconds.divmod(count)
        "#{n.to_i} #{name}"
      end
    end.compact.reverse.join(' ')
  end

  def banner
    puts ''
    puts '   ____ _  _ ____ ____   ___  ____ ____ ____ _ _    ____ ____'
    puts "   |___ |--| |=== |---   |--' |--< [__] |--- | |___ |=== |--<"
    puts ''
  end

  def report
    if run_status.success?
      run_time  = humanize(run_status.elapsed_time)
      updates   = run_status.updated_resources.length
      total     = run_status.all_resources.length

      all_resources.each do |r|
        @cookbooks[r.cookbook_name]                      += r.elapsed_time
        @recipes["#{r.cookbook_name}::#{r.recipe_name}"] += r.elapsed_time
        @resources["#{r.resource_name}[#{r.name}]"]       = r.elapsed_time
      end

      max_time = all_resources.max_by(&:elapsed_time).elapsed_time
      slow_resource = all_resources.max_by { |r| full_name(r).length }

      banner
      puts 'Elapsed Time  Cookbook             Version'.yellow
      puts '------------  -------------------  --------------------------'.green
      @cookbooks.sort_by { |_, v| -v }.each do |cookbook, elapsed_time|
        ver = run_context.cookbook_collection[cookbook.to_sym].version
        printf "%19f %-20s %-7s\n", elapsed_time, cookbook, ver
      end
      puts ''
      puts 'Elapsed Time  Recipe'.orange
      puts '------------  -----------------------------------------------'.green
      @recipes.sort_by { |_, v| -v }.each do |recipe, elapsed_time|
        printf "%19f  %s\n", elapsed_time, recipe
      end
      puts ''
      puts 'Elapsed Time  Resource'.orange
      puts '------------  -----------------------------------------------'.green
      @resources.sort_by { |_, v| -v }.each do |resource, elapsed_time|
        printf "%19f  %s\n", elapsed_time, resource
      end
      puts "\n+----------------------------------------------------------" \
           "--------------------+\n".purple
      puts ''
      puts "Chef Run Completed in #{run_time} on #{node.name}. Updated " \
           "#{updates} of #{total} resources."

      puts
      printf "Slowest Resource: #{full_name(slow_resource)} (%.6fs)\n", max_time
      puts ''
      puts Faker::Hacker.say_something_smart
      puts ''

    elsif run_status.failed?
      banner
      puts "Chef FAILED in #{run_time} on #{node.name} with exception:".orange
      puts run_status.formatted_exception
    end
  end
end
