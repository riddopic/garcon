# encoding: UTF-8
#

require 'chef'
require 'chef/log'
require 'chef/handler'

class DevReporter < Chef::Handler
  attr_reader :resources, :immediate, :delayed, :always

  def initialize(opts = {})
    @resources = opts.fetch(:resources, true)
    @immediate = opts.fetch(:immediate, true)
    @delayed   = opts.fetch(:delayed,   true)
  end

  def generate_message
    res = if @resources
      resources_list
    elsif @immediate
      immediate_list
    elsif @delayed
      delayed_list
    else
      'No Collection of Reportable Chefs to Collect on enabled'
    end
    "\n]--(-)--(----------)----------------------(-----------)--(-)--["
    "\n]------------------[  Le (hef (ollection  ]-------------------["
    "\n]--[-]--[----------]----------------------[-----------]--[-]--[\n\n#{res}"
  end

  def full_name(resource)
    "#{expand_on(resource.resource_name)}[#{expand_on(resource.name)}]"
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

  def __resources_list__
    rcrcar = run_context.resource_collection.all_resources
    rcrcar.collect { |res| "#{res.resource_name}[#{res.name}] =>\n" }
  end

  def resources_list
    list = run_context.resource_collection.all_resources.collect do |res|
      "#{res.resource_name}[#{res.name}] =>\n"
    end
    "\n** Resource List **\n\n#{__resources_list__}"
  end

  def __immediate_list__
    rcinc = run_context.immediate_notification_collection
    rcinc.collect { |notify, value| "#{notify} =>\n  #{value.join("\n  ")}\n" }
  end

  def immediate_list
    "\n** Immediate Notification List **\n\n#{__immediate_list__}"
  end

  def __delayed_list__
    rcdnc = run_context.delayed_notification_collection
    rcdnc.collect { |notify, value| "#{notify} =>\n  #{value.join("\n  ")}" }
  end

  def delayed_list
    "\n** Delayed Notifications List **\n\n#{__delayed_list__}"
  end

  def report
    if run_status.success?
      cookbooks = Hash.new(0)
      recipes   = Hash.new(0)
      resources = Hash.new(0)

      all_resources.each do |r|
        cookbooks[r.cookbook_name]                      += r.elapsed_time
        recipes["#{r.cookbook_name}::#{r.recipe_name}"] += r.elapsed_time
        resources["#{r.resource_name}[#{r.name}]"]       = r.elapsed_time
      end

      @max_time = all_resources.max_by { |r| r.elapsed_time      }.elapsed_time
      @max      = all_resources.max_by { |r| full_name(r).length }

      Chef::Log.info ''
      Chef::Log.info 'Elapsed_time  Cookbook'
      Chef::Log.info '------------  ----------------' \
                     ' - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      cookbooks.sort_by { |_k, v| -v }.each do |cookbook, run_time|
        Chef::Log.info '%12f  %s' % [run_time, cookbook]
      end
      Chef::Log.info ''
      Chef::Log.info 'Elapsed Time  Rec'
      Chef::Log.info '------------  ----------------' \
                     ' - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      recipes.sort_by { |_k, v| -v }.each do |recipe, run_time|
        Chef::Log.info '%12f  %s' % [run_time, recipe]
      end
      Chef::Log.info ''
      Chef::Log.info 'Elapsed_time  Resource'
      Chef::Log.info '------------  ----------------' \
                     ' - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      resources.sort_by { |_k, v| -v }.each do |resource, run_time|
        Chef::Log.info '%12f  %s' % [run_time, resource]
      end

      Chef::Log.info ''
      # Chef::Log.info "Slowest Resource: #{full_name(@max)} (%.6fs)"%[@max_time]
      Chef::Log.info ''
      Chef::Log.info(generate_message) if run_status.success?
      Chef::Log.info ''
    end
  end
end
