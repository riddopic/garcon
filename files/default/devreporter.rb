# encoding: UTF-8
#

require 'chef'
require 'chef/log'
require 'chef/handler'

class DevReporter < Chef::Handler
  attr_reader :resources, :immediate, :delayed, :always

  def initialize(opts = {})
    @data = opts[:data]
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

  def report
    if run_status.success?
      cookbooks = Hash.new(0)
      recipes   = Hash.new(0)
      resources = Hash.new(0)
      run_time  = humanize(run_status.elapsed_time)
      updates   = run_status.updated_resources.length
      total     = run_status.all_resources.length

      all_resources.each do |r|
        cookbooks[r.cookbook_name]                      += r.elapsed_time
        recipes["#{r.cookbook_name}::#{r.recipe_name}"] += r.elapsed_time
        resources["#{r.resource_name}[#{r.name}]"]       = r.elapsed_time
      end

      @max_time = all_resources.max_by { |r| r.elapsed_time      }.elapsed_time
      @max      = all_resources.max_by { |r| full_name(r).length }

      # Droping puts because mash grinder faceplanted logging changes.
      puts <<-EOF
                              .:  ;:. .:;S;:. .:;.;:. .:;S;:. .:;S;:.
                              S   ' S S  S    S  S    S     S  /
                              `:;S;:' `:;S;:' `:;S;:' `:;S;:' `:;S;:'
              .g8"""bgd
            .dP'     `M
            dM'       `  ,6"Yb.  `7Mb,od8 ,p6"bo   ,pW"Wq.`7MMpMMMb.
            MM          8)   MM    MM' "'6M'  OO  6W'   `Wb MM    MM
            MM.    `7MMF',pm9MM    MM    8M       8M     M8 MM    MM
            `Mb.     MM 8M   MM    MM    YM.    , YA.   ,A9 MM    MM
              `"bmmmdPY `Moo9^Yo..JMML.   YMbmd'   `Ybmd9'.JMML  JMML.
                                            bog
                                             od
      EOF
      puts 'Elapsed Time  Cookbook'
      puts '------------  -------------------------------------------'
      cookbooks.sort_by { |k, v| -v }.each do |cookbook, run_time|
        puts '%19f  %s' % [run_time, cookbook]
      end
      puts ''
      puts 'Elapsed Time  Recipe'
      puts '------------  -------------------------------------------'
      recipes.sort_by { |k, v| -v }.each do |recipe, run_time|
        puts '%19f  %s' % [run_time, recipe]
      end
      puts ''
      puts 'Elapsed Time  Resource'
      puts '------------  -------------------------------------------'
      resources.sort_by { |k, v| -v }.each do |resource, run_time|
        puts '%19f  %s' % [run_time, resource]
      end
      puts '+------------------------------------------------------------------+'
      puts ''
      puts "Chef Run Completed in #{run_time} on #{node.name}. Updated " \
           "#{updates} of #{total} resources."

      cookbooks = run_context.cookbook_collection
      puts
      puts "✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘"
      puts "****** Cookbooks: #{cookbooks.keys.map { |x| cookbooks[x].name.to_s + " " + cookbooks[x].version} }"
      puts "✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘ ✗ ✘"
      puts
      puts "Slowest Resource: #{full_name(@max)} (%.6fs)"%[@max_time]
      puts ''
      puts "#{@data}"
      puts ''
    elsif run_status.failed?
      puts "Chef Run FAILED in #{run_time} on #{node.name} with the exception:"
      puts run_status.formatted_exception
    end
  end
end
