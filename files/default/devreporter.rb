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
      cookbooks = Hash.new(0)
      recipes   = Hash.new(0)
      resources = Hash.new(0)

      all_resources.each do |r|
        cookbooks[r.cookbook_name]                      += r.elapsed_time
        recipes["#{r.cookbook_name}::#{r.recipe_name}"] += r.elapsed_time
        resources["#{r.resource_name}[#{r.name}]"]       = r.elapsed_time
      end

      @max_time     = all_resources.max_by { |r| r.elapsed_time      }.elapsed_time
      @max_resource = all_resources.max_by { |r| full_name(r).length }

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
require 'rubygems'
require 'chef'
require 'chef/handler'

class ChefCollection < Chef::Handler
    attr_reader :resources, :immediate, :delayed, :always

    def initialize(options = defaults)
      @resources = options[:resources]
      @immediate = options[:immediate]
      @delayed = options[:delayed]
      @always = options[:always]
    end

    def defaults
      return {
        :resources => true,
        :immediate => true,
        :delayed => true,
        :always => true
      }
    end

    def generate_message
      list = ""
      if @resources
        list += resources_list
      elsif @immediate
        list += immediate_list
      elsif @delayed
        list += delayed_list
      else
        return "No parameters enabled; skipping ChefCollection Report"
      end
      return "\n==================== ChefCollection Report =====================\n\n#{list}"
    end

    def resources_list
      list = run_context.resource_collection.all_resources.collect do |res|
        "#{res.resource_name}[#{res.name}] =>\n"
      end
      return "\n** Resource List **\n\n#{list}"
    end

    def immediate_list
      list = run_context.immediate_notification_collection.collect do |notif, vals|
        "#{notif} =>\n  #{vals.join("\n  ")}\n"
      end
      return "\n** Immediate Notifications List **\n\n#{list}"
    end

    def delayed_list
      list = run_context.delayed_notification_collection.collect do |notif, vals|
        "#{notif} =>\n  #{vals.join("\n  ")}"
      end
      return "\n** Delayed Notifications List **\n\n#{list}"
    end

    def report
      if @always || run_status.success?
        Chef::Log.info(generate_message)
      else
        Chef::Log.warn 'ChefCollection disabled; run either failed or :always parameter set to false'
      end
    end

end

require 'rubygems'
require 'chef'
require 'chef/handler'

class ChefMOTD < Chef::Handler
    attr_reader :priority, :keep_old_entries

    def initialize(options = defaults)
      @priority = options[:priority]
      @keep_old_entries = options[:keep_old_entries]
      @failure_message = options[:failure_message]
      @print_resources = options[:print_resources]
    end

    def report
      if run_status.success?
        Chef::Log.info 'Updating Chef info in MOTD ...'
        delete_outdated
        write_out(generate_message)
      else
        if @failure_message then write_out(failure_message) end
      end
    end

    private

    def defaults
      return {
        priority: '05',
        keep_old_entries: false,
        failure_message: false,
        print_resources: true
      }
    end

    def delete_outdated
      if @keep_old_entries then return end
      Dir.entries('/etc/update-motd.d').select do |entry|
        /chef-motd/.match(entry) && !/^#{@priority}/.match(entry)
      end.each do |del|
        Chef::Log.warn "Deleting #{del} as it does not match the current ChefMOTD priority"
        FileUtils.rm ::File.join('/etc', 'update-motd.d', del)
      end
    end

    def write_out(msg)
      file = "/etc/update-motd.d/#{@priority}-chef-motd"
      ::File.open(file, 'w') {|f| f.puts msg}
      ::File.chmod(0755, file)
    end

    def generate_message
      msg = <<-eos
#!/bin/sh
echo \"Node #{node.name} last success at #{Time.now.to_s} in #{run_status.elapsed_time} seconds\"
echo \"Updated resources on last run (total: #{run_status.updated_resources.length}):\"
      eos
      if @print_resources
        run_status.updated_resources.each do |res|
          msg += "echo \"  #{res.resource_name}[#{res.name}]\"\n"
        end
      end
      return msg
    end

    def failure_message
      return <<-eos
#!/bin/sh
echo \"Node #{node.name} Chef run failed at #{Time.now.to_s} in #{run_status.elapsed_time} seconds\"
      eos
    end
end
