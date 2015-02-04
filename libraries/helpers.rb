# encoding: UTF-8
#
# Cookbook Name:: garcon
# Libraries:: helpers
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

require 'openssl'
require 'base64'
require 'securerandom'

# Helper methods for cookbook.
#
module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Helpers
    include Chef::Mixin::ShellOut

    # Check to see if the recipe has already been included, if not include it.
    # It will return false if it has already been run or return the last value
    # of the includeed recipe.
    #
    # @param [String] recipe
    #   the recipe to include only once
    #
    # @return [TrueClass, FalseClass]
    #   false if it's already been run
    #
    def single_include(recipe)
      node.run_context.loaded_recipe?(recipe) ? false : (include_recipe recipe)
    end

    # Returns a salted PBKDF2 hash of the password.
    #
    # @param password [String]
    #   password to hash
    #
    # @return [String]
    #   salted PBKDF2 hash of the password provided.
    #
    def create_hash(password)
      salt = SecureRandom.base64(24)
      pbkdf2 = OpenSSL::PKCS5::pbkdf2_hmac_sha1(password, salt, 1000, 24)
      Base64.encode64(pbkdf2)
    end

    # Return a cleanly join URI/URL segments into a cleanly normalized URL
    # that the libraries can use when constructing URIs. URI.join is pure
    # evil.
    #
    # @param [Array<String>] paths
    #   the list of parts to join
    #
    # @return [URI]
    #
    def uri_join(*paths)
      return nil if paths.length == 0
      leadingslash = paths[0][0] == '/' ? '/' : ''
      trailingslash = paths[-1][-1] == '/' ? '/' : ''
      paths.map! { |path| path.sub(/^\/+/, '').sub(/\/+$/, '') }
      leadingslash + paths.join('/') + trailingslash
    end

    # Finds a command in $PATH
    #
    # @param [String] cmd
    #   the command to find
    #
    # @return [String, nil]
    #
    def which(cmd)
      if Pathname.new(cmd).absolute?
        File.executable?(cmd) ? cmd : nil
      else
        paths = %w(/bin /usr/bin /sbin /usr/sbin)
        paths << ENV.fetch('PATH').split(::File::PATH_SEPARATOR)
        paths.flatten.uniq.each do |path|
          possible = ::File.join(path, cmd)
          return possible if ::File.executable?(possible)
        end
        nil
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
    def cookbook_version(name = nil)
      cookbook = name.nil? ? cookbook_name : name
      node.run_context.cookbook_collection[cookbook].metadata.version
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
      !which(cmd).nil?
    end

    def monitor
      @@monitor ||= Monitor.new
    end

    # Helper method to get Aria2 installed, enables the yum repo, installs then
    # removes the repo.
    def prerequisite
      monitor.synchronize do
        package('gnutls') { action :nothing }.run_action(:install)
        chef_gem('rubyzip') { action :nothing }.run_action(:install)
        Chef::Recipe.send(:require, 'zip')
        unless installed?('aria2c')
          if platform_family?('rhel') && node[:platform_version].to_i == 7
            Chef::Log.info shell_out!('rpm -Uvh http://bit.ly/1xWL2LX').stdout
          else
            begin
              yum = Chef::Resource::YumRepository.new('garcon', run_context)
              yum.mirrorlist node[:garcon][:repo][:mirrorlist]
              yum.gpgcheck node[:garcon][:repo][:gpgcheck]
              yum.gpgkey node[:garcon][:repo][:gpgkey]
              yum.run_action(:create)
              package('aria2') { action :nothing }.run_action(:install)
            ensure
              yum.run_action(:delete)
            end
          end
        end
      end
    end

    def count
      @@count ||= 0
      @@count += 1
    end

    def announce(msg = nil)
      ca = "#{caller[1][/`.*'/][1..-2]}".yellow
      co = "#{count}".purple
      s = '⏐'.green
      msg = msg.nil? ? nil : msg.cyan
      log.info "#{self.class} #{s} #{ca} #{s} #{co} #{s} #{msg}"
    end

    def banner(msg = nil, color = :orange)
      msg = msg.nil? ? nil : msg
      log.info "#{msg}".send(color.to_sym)
    end

    def highlight
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.magenta
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.on_yellow
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.yellow
    end
    alias_method :h1, :highlight

    def h2
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.magenta
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.on_magenta
      log.info '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡｡' \
               '｡｡｡｡｡｡'.yellow
    end

    # Unshorten a shortened URL
    #
    # @param url [String] A shortened URL
    # @param [Hash] opts
    # @option opts [Integer] :max_level
    #   max redirect times
    # @option opts [Integer] :timeout
    #   timeout in seconds, for every request
    # @option opts [TrueClass, FalseClass] :use_cache
    #   use cached result if available
    #
    # @return Original url, a url that does not redirects
    def unshorten(url, opts= {})
      options = {
        max_level: opts.fetch(:max_level, 10),
        timeout:   opts.fetch(:timeout, 2),
        use_cache: opts.fetch(:use_cache, true)
      }
      url = (url =~ /^https?:/i) ? url : "http://#{url}"
      __unshorten__(url, options)
    end

    private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

    @@cache = { }

    # @!visibility private
    def __unshorten__(url, options, level = 0)
      return @@cache[url] if options[:use_cache] && @@cache[url]
      return url if level >= options[:max_level]
      uri = URI.parse(url) rescue nil
      return url if uri.nil?

      http = Net::HTTP.new(uri.host, uri.port)
      http.open_timeout = options[:timeout]
      http.read_timeout = options[:timeout]
      http.use_ssl = true if uri.scheme == 'https'

      if uri.path && uri.query
        response = http.request_head("#{uri.path}?#{uri.query}") rescue nil
      elsif uri.path && !uri.query
        response = http.request_head(uri.path) rescue nil
      else
        response = http.request_head('/') rescue nil
      end

      if response.is_a? Net::HTTPRedirection and response['location'] then
        location = URI.encode(response['location'])
        location = (uri + location).to_s if location
        @@cache[url] = __unshorten__(location, options, level + 1)
      else
        url
      end
    end
  end

  class Exceptions
    # A custom exception class for not implemented methods
    class MethodNotImplemented < NotImplementedError
      def initialize(method)
        super("Method '#{method}' needs to be implemented")
      end
    end
    class InvalidPort < ArgumentError; end
  end

  unless Chef::Recipe.ancestors.include?(Garcon::Helpers)
    Chef::Recipe.send(:include, Garcon::Helpers)
    Chef::Resource.send(:include, Garcon::Helpers)
    Chef::Provider.send(:include, Garcon::Helpers)
  end
end
