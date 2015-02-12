# encoding: UTF-8
#

require 'chef'
require 'chef/log'
require 'chef/handler'

class DevReporter < Chef::Handler
  attr_reader :always, :path

  def initialize(options = defaults)
    @always = options[:always]
    @path   = options[:path]
  end

  def defaults
    { always: true, path: Chef::Config[:file_cache_path] }
  end

  def full_name(resource)
    "#{resource.resource_name}[#{resource.name}]"
  end

  def report
    if @always || run_status.success?
      # reports the execution time spent in each: cookbook, recipe, and resource
      cookbooks = Hash.new(0)
      recipes   = Hash.new(0)
      resources = Hash.new(0)

      # collect all profiled timings and group by type
      all_resources.each do |r|
        cookbooks[r.cookbook_name] += r.elapsed_time
        recipes["#{r.cookbook_name}::#{r.recipe_name}"] += r.elapsed_time
        resources["#{r.resource_name}[#{r.name}]"] = r.elapsed_time
      end

      @max_time = all_resources.max_by{ |r| r.elapsed_time}.elapsed_time
      @max_resource = all_resources.max_by{ |r| full_name(r).length}

      # print each timing by group, sorting with highest elapsed time first
      Chef::Log.info ''
      Chef::Log.info 'Elapsed_time  Cookbook'
      Chef::Log.info '------------  ---------------- - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      cookbooks.sort_by { |_k, v| -v }.each do |cookbook, run_time|
        Chef::Log.info '%12f  %s' % [run_time, cookbook]
      end
      Chef::Log.info ''
      Chef::Log.info 'Elapsed Time  Rec'
      Chef::Log.info '------------  ---------------- - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      recipes.sort_by { |_k, v| -v }.each do |recipe, run_time|
        Chef::Log.info '%12f  %s' % [run_time, recipe]
      end
      Chef::Log.info ''
      Chef::Log.info 'Elapsed_time  Resource'
      Chef::Log.info '------------  ---------------- - - - - - - - - - - -  -  -  -  -  -  -  -  -  -'
      resources.sort_by { |_k, v| -v }.each do |resource, run_time|
        Chef::Log.info '%12f  %s' % [run_time, resource]
      end
      Chef::Log.info ''
      Chef::Log.info "Slowest Resource : #{full_name(@max_resource)} (%.6fs)"%[@max_time]
      Chef::Log.info ''
      # exports node data to disk at the end of a successful Chef run
      Chef::Log.info "Writing node information to #{@path}/successful-run-data.json"
      Chef::FileCache.store('successful-run-data.json', Chef::JSONCompat.to_json_pretty(data), 0640)
    else
      Chef::Log.warn 'DevReporter disabled; run either failed or :always parameter set to false'
    end
  end
end
