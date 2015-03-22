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

require_relative '../exceptions'

module Garcon
  # More sweetness syntactical sugar for our Pâtissier.
  #
  module ChefHelpers
    # Methods are also available as module-level methods as well as a mixin.
    extend self

    include Chef::Mixin::ShellOut
    include Garcon::Exceptions

    # Search for a matching node by a given role or tag.
    #
    # @param [Symbol] type
    #   The filter type, can be `:role` or `:tag`.
    #
    # @param [String] filter
    #   The role or tag to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by(type, filter, single = true, &block)
      nodes = []
      env   = node.chef_environment
      if node.public_send(Inflections.pluralize(type.to_s)).include? filter
        nodes << node
      end
      if !single || nodes.empty?
        search(:node, "#{type}:#{filter} AND chef_environment:#{env}") do |n|
          nodes << n
        end
      end

      if block_given?
        nodes.each { |n| yield n }
      else
        single ? nodes.first : nodes
      end
    end

    # Search for a matching node by role.
    #
    # @param [String] role
    #   The role to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by_role(role, single = true, &block)
      find_matching(:role, role, single, block)
    end

    # Search for a matching node by tag.
    #
    # @param [String] tag
    #   The role or tag to filter on.
    #
    # @param [Boolean] single
    #   True if we should return only a single match, or false to return all
    #   of the matches.
    #
    # @yield an optional block to enumerate over the nodes.
    #
    # @return [Array, Proc]
    #   The value of the passed block or node.
    #
    # @api public
    def find_by_tag(tag, single = true, &block)
      find_matching(:tag, tag, single, block)
    end

    alias_method :find_matching,      :find_by
    alias_method :find_matching_role, :find_by_role
    alias_method :find_matching_tag,  :find_by_tag

    def verify_options(accepted, actual) # @private
      return unless debug || $DEBUG
      unless (act=Set[*actual.keys]).subset?(acc=Set[*accepted])
        raise Croesus::Errors::UnknownOption,
          "\nDetected unknown option(s): #{(act - acc).to_a.inspect}\n" <<
          "Accepted options are: #{accepted.inspect}"
      end
      yield if block_given?
    end

    # Returns the columns and lines of the current tty.
    #
    # @return [Integer]
    #   Number of columns and lines of tty, returns [0, 0] if no tty is present.
    #
    def terminal_dimensions
      [0, 0] unless  STDOUT.tty?
      [80, 40] if OS.windows?

      if ENV['COLUMNS'] && ENV['LINES']
        [ENV['COLUMNS'].to_i, ENV['LINES'].to_i]
      elsif ENV['TERM'] && command_in_path?('tput')
        [`tput cols`.to_i, `tput lines`.to_i]
      elsif command_in_path?('stty')
        `stty size`.scan(/\d+/).map {|s| s.to_i }
      else
        [0, 0]
      end
    rescue
      [0, 0]
    end

    # Checks in PATH returns true if the command is found.
    #
    # @param [String] command
    #   The name of the command to look for.
    #
    # @return [Boolean]
    #   True if the command is found in the path.
    #
    def command_in_path?(command)
      found = ENV['PATH'].split(File::PATH_SEPARATOR).map do |p|
        File.exist?(File.join(p, command))
      end
      found.include?(true)
    end

    # Returns true if the current node is a docker container, otherwise
    # false.
    #
    # @return [Boolean]
    #
    # @api public
    def docker?
      ::File.exist?('/.dockerinit') || ::File.exist?('/.dockerenv')
    end

    # Returns true if the current node has selinux enabled, otherwise false.
    #
    # @return [Boolean]
    #
    # @api public
    def selinux?
      if installed?('getenforce')
        Mixlib::ShellOut.new('getenforce').run_command.stdout != "Disabled\n"
      else
        false
      end
    end

    # Retrieve the version number of the cookbook in the run list.
    #
    # @param name [String]
    #   name of cookbook to retrieve the version on.
    #
    # @return [Integer]
    #   version of the cookbook.
    #
    # @api public
    def cookbook_version(name = nil)
      cookbook = name.nil? ? cookbook_name : name
      node.run_context.cookbook_collection[cookbook].metadata.version
    end

    # Shortcut to return cache path, if you pass in a file it will return
    # the file with the cache path.
    #
    # @example
    #   file_cache_path
    #     => "/var/chef/cache/"
    #
    #   file_cache_path 'patch.tar.gz'
    #     => "/var/chef/cache/patch.tar.gz"
    #
    #   file_cache_path "#{node[:name]}-backup.tar.gz"
    #     => "/var/chef/cache/c20d24209cc8-backup.tar.gz"
    #
    # @param [String] args
    #   name of file to return path with file
    #
    # @return [String]
    #
    # @api public
    def file_cache_path(*args)
      if args.nil?
        Chef::Config[:file_cache_path]
      else
        ::File.join(Chef::Config[:file_cache_path], args)
      end
    end

    # Invokes the public method whose name goes as first argument just like
    # `public_send` does, except that if the receiver does not respond to
    # it the call returns `nil` rather than raising an exception.
    #
    # @note `_?` is defined on `Object`. Therefore, it won't work with
    # instances of classes that do not have `Object` among their ancestors,
    # like direct subclasses of `BasicObject`.
    #
    # @param [String] object
    #   The object to send the method to.
    #
    # @param [Symbol] method
    #   The method to send to the object.
    #
    # @api public
    def _?(*args, &block)
      if args.empty? && block_given?
        yield self
      else
        resp = public_send(*args[0], &block) if respond_to?(args.first)
        return nil if resp.nil?
        !!resp == resp ? args[1] : [args[1], resp]
      end
    end

    # Returns a hash using col1 as keys and col2 as values.
    #
    # @example zip_hash([:name, :age, :sex], ['Earl', 30, 'male'])
    #   => { :age => 30, :name => "Earl", :sex => "male" }
    #
    # @param [Array] col1
    #   Containing the keys.
    #
    # @param [Array] col2
    #   Values for hash.
    #
    # @return [Hash]
    #
    def zip_hash(col1, col2)
      col1.zip(col2).inject({}) { |r, i| r[i[0]] = i[1]; r }
    end

    # Amazingly and somewhat surprisingly comma separate a number
    #
    # @param [Integer] num
    #
    # @return [String]
    #
    # @api public
    def comma_separate(num)
      num.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\\1,').reverse
    end

    # Creates a temp directory executing the block provided. When done the
    # temp directory and all it's contents are garbage collected.
    #
    # @yield [Proc] block
    #   A block that will be run
    #
    # @return [Object]
    #   Result of the block operation
    #
    # @api public
    def with_tmp_dir(&block)
      Dir.mktmpdir(SecureRandom.hex(3)) do |tmp_dir|
        Dir.chdir(tmp_dir, &block)
      end
    end

    # Boolean method to check if a command line utility is installed.
    #
    # @param [String] cmd
    #   the command to find
    #
    # @return [TrueClass, FalseClass]
    #   true if the command is found in the path, false otherwise
    #
    def installed?(cmd)
      !Garcon::FileHelper.which(cmd).nil?
    end

    # @return [String] object inspection
    # @api public
    def inspect
      instance_variables.inject([
        "\n#<#{self.class}:0x#{self.object_id.to_s(16)}>",
        "\tInstance variables:"
      ]) do |result, item|
        result << "\t\t#{item} = #{instance_variable_get(item)}"
        result
      end.join("\n")
    end

    # @return [String] string of instance
    # @api public
    def to_s
      "<#{self.class}:0x#{self.object_id.to_s(16)}>"
    end
  end
end
