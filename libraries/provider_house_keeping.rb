# encoding: UTF-8
#
# Cookbook Name:: garcon
# Provider:: house_keeping
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

require 'date'

# House keeping service
#
class Chef::Provider::HouseKeeping < Chef::Provider
  include Garcon

  provides :house_keeping

  def initialize(new_resource, run_context)
    super(new_resource, run_context)
  end

  # Boolean indicating if WhyRun is supported by this provider
  #
  # @return [TrueClass, FalseClass]
  #
  # @api private
  def whyrun_supported?
    true
  end

  # Load and return the current resource
  #
  # @return [Chef::Provider::HouseKeeping]
  #
  # @api private
  def load_current_resource
    @current_resource = PurgeFlushBinge.new(new_resource)
    @current_resource.exclude(new_resource.exclude) if new_resource.exclude

    @current_resource
  end

  def action_purge
    if @current_resource.num_files > 1
      path  = new_resource.path
      age   = new_resource.age
      size  = new_resource.size
      dsize = new_resource.directory_size
      num   = @current_resource.num_files
      purge = {}
      purge.merge!(@current_resource.older_than(age))    unless age.nil?
      purge.merge!(@current_resource.larger_than(size))  unless size.nil?
      purge.merge!(@current_resource.to_dir_size(dsize)) unless dsize.nil?
      num_purged = purge.length

      converge_by "Processed #{num} files from #{path}, #{num_purged} purged" do
        if purge.length > 1
          purge.each do |file, data|
            file file do
              force_unlink          new_resource.force_unlink
              manage_symlink_source new_resource.manage_symlink_source
              backup  false
              action :nothing
            end
          end
          new_resource.updated_by_last_action(true)
        end
      end
    end
  end

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  class PurgeFlushBinge
    def initialize(new_resource)
      search_path = if new_resource.recursive
        ::File.join(new_resource.path, '**', '*')
      else
        ::File.join(new_resource.path, '*')
      end
      @file_map = Hash.new
      @dir_size = 0

      Dir[search_path].select { |f| ::File.file?(f) }.map do |file|
        fstat = ::File.stat(file)
        @dir_size += fstat.size
        @file_map.store(file,
          ctime: fstat.ctime.to_i,
          mtime: fstat.mtime.to_i,
          size:  fstat.size)
      end
    end

    def older_than(days)
      purge_time = Time.now - (60 * 60 * 24 * days.to_i)
      @file_map.select { |file, data| data[:mtime] < purge_time.to_i }
    end

    def larger_than(size)
      @file_map.select do |file, data|
        c = Humanize.new(size.to_s)
        data[:size].to_f > c.to_size(:b).to_f
      end
    end

    def to_dir_size(size)
      sorted = @file_map.sort_by { |k,v| v[:mtime] }
      c = Humanize.new(size.to_s)
      delete_size = @dir_size - c.to_size(:b).to_f
      return {} if delete_size <= 0

      f_size = 0
      list   = {}
      sorted.each do |f|
        list[f[0]] = f[1]
        f_size += f[1][:size]
        break if f_size >= delete_size
      end
      list
    end

    def exclude(regexp)
      @file_map.delete_if { |file| file.match(Regexp.new(regexp)) }
    end

    def num_files
      @file_map.length
    end
  end

  class Humanize
    def initialize(size)
      @units = { b: 1, kb: 1024**1, mb: 1024**2, gb: 1024**3, tb: 1024**4 }
      @size_int = size.partition(/\D{1,2}/).at(0).to_i
      unit = size.partition(/\D{1,2}/).at(1).to_s.downcase
      case
      when unit.match(/[kmgtpe]{1}/)
        @size_unit = unit.concat('b')
      when unit.match(/[kmgtpe]{1}b/)
        @size_unit = unit
      else
        @size_unit = 'b'
      end
    end

    def to_size(unit, places = 1)
      unit_val = @units[unit.to_s.downcase.to_sym]
      bytes    = @size_int * @units[@size_unit.to_sym]
      size     = bytes.to_f / unit_val.to_f
      sprintf("%.#{places}f", size).to_f
    end

    def from_size(places = 1)
      unit_val = @units[@size_unit.to_s.downcase.to_sym]
      sprintf("%.#{places}f", @size_int * unit_val)
    end
  end
end

