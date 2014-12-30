# encoding: UTF-8
#
# Cookbook Name:: garcon
# Lobraries:: garcon
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2014-2015 Stefano Harding
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

# Helper methods for cookbook.
#
module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Helpers
    def monitor
      @@monitor ||= Monitor.new
    end

    # Helper method to get Aria2 installed, enables the yum repo, installs then
    # removes the repo.
    def prerequisite
      unless installed?('aria2c')
        monitor.synchronize do
          package('gnutls') { action :nothing }.run_action(:install)
          yum = Chef::Resource::YumRepository.new('garcon', run_context)
          yum.mirrorlist node[:garcon][:repo][:mirrorlist]
          yum.gpgcheck node[:garcon][:repo][:gpgcheck]
          yum.gpgkey node[:garcon][:repo][:gpgkey]
          yum.run_action(:create)
          package('aria2') { action :nothing }.run_action(:install)
          yum.run_action(:delete)
        end
      end
    end

    # Runs the recipe in it's own thread. NOTE: You need to ensure that the
    # recipe is thread safe and non-blocking.
    #
    # @param [String] recipe
    #   the recipe to run
    #
    def threaded_include(recipe)
      thread name { block { run_context.include_recipe recipe }}
    end


    def recipe_block(description, &block)
      recipe = self
      ruby_block "recipe_block[#{description}]" do
        block do
          recipe.instance_eval(&block)
        end
      end
    end


    def timers_for(jobs = [])
      timers = Hoodie::Timers::Group.new
      jobs.each.with_index(1) do |job, i|
        timers.every(10+i+i) do
          Chef::Log.info "#{job}: #{job.state}" unless job.fulfilled?
        end
      end

      begin
        Timeout.timeout(300) do
          until jobs.map { |job| job.fulfilled? }
            jobs.each { |j| fail "#{j} #{j.state}: #{j.reason}" if j.rejected? }
            sleep 3
            timers.wait
          end
        end
      rescue Timeout::Error
        Chef::Log.error 'Timeout waiting for threads:'
        jobs.each { |j| Chef::Log.error "#{j}: #{j.state}" }
        fail 'Failure due to Timeout::Error waiting on threads.'
      ensure
        timers.cancel
      end
    end
  end

  unless Chef::Recipe.ancestors.include?(Garcon::Helpers)
    Chef::Recipe.send(:include, Garcon::Helpers)
    Chef::Resource.send(:include, Garcon::Helpers)
    Chef::Provider.send(:include, Garcon::Helpers)
  end
end

class String
  def clear;      colorize(self, "\e[0m");    end
  def erase_line; colorize(self, "\e[K");     end
  def erase_char; colorize(self, "\e[P");     end
  def bold;       colorize(self, "\e[1m");    end
  def dark;       colorize(self, "\e[2m");    end
  def underline;  colorize(self, "\e[4m");    end
  def blink;      colorize(self, "\e[5m");    end
  def reverse;    colorize(self, "\e[7m");    end
  def concealed;  colorize(self, "\e[8m");    end
  def black;      colorize(self, "\e[0;30m"); end
  def gray;       colorize(self, "\e[1;30m"); end
  def red;        colorize(self, "\e[0;31m"); end
  def magenta;    colorize(self, "\e[1;31m"); end
  def green;      colorize(self, "\e[0;32m"); end
  def olive;      colorize(self, "\e[1;32m"); end
  def yellow;     colorize(self, "\e[0;33m"); end
  def cream;      colorize(self, "\e[1;33m"); end
  def blue;       colorize(self, "\e[0;34m"); end
  def purple;     colorize(self, "\e[1;34m"); end
  def orange;     colorize(self, "\e[0;35m"); end
  def mustard;    colorize(self, "\e[1;35m"); end
  def cyan;       colorize(self, "\e[0;36m"); end
  def cyan2;      colorize(self, "\e[1;36m"); end
  def white;      colorize(self, "\e[0;97m"); end
  def on_black;   colorize(self, "\e[40m");   end
  def on_red;     colorize(self, "\e[41m");   end
  def on_green;   colorize(self, "\e[42m");   end
  def on_yellow;  colorize(self, "\e[43m");   end
  def on_blue;    colorize(self, "\e[44m");   end
  def on_magenta; colorize(self, "\e[45m");   end
  def on_cyan;    colorize(self, "\e[46m");   end
  def on_white;   colorize(self, "\e[47m");   end
  def colorize(text, color_code) "#{color_code}#{text}\e[0m" end
end
