# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: resource_zip_file
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

class Chef::Resource::ZipFile < Chef::Resource
  include Garcon

  # The module where Chef should look for providers for this resource
  #
  # @param [Module] arg
  #   the module containing providers for this resource
  # @return [Module]
  #   the module containing providers for this resource
  # @api private
  provider_base Chef::Provider::ZipFile

  # The value of the identity attribute
  #
  # @return [String]
  #   the value of the identity attribute.
  # @api private
  identity_attr :path

  # Maps a short_name (and optionally a platform and version) to a
  # Chef::Resource
  #
  # @param [Symbol] arg
  #   short_name of the resource
  # @return [Chef::Resource::ZipFile]
  #   the class of the Chef::Resource based on the short name
  # @api private
  provides :zip_file, os: 'linux'

  # Set or return the list of `state attributes` implemented by the Resource,
  # these are attributes that describe the desired state of the system
  #
  # @return [Chef::Resource::ZipFile]
  # @api private
  state_attrs :checksum, :owner, :group, :mode

  # Adds actions to the list of valid actions for this resource
  #
  # @return [Chef::Resource::ZipFile]
  # @api public
  actions :zip, :unzip

  # Sets the default action
  #
  # @return [undefined]
  # @api private
  default_action :unzip

  def initialize(name, run_context = nil)
    super
    @path = name
    @resource_name = :zip_file
  end

  # The full path to the file, including the file name and its extension,
  # default value: the name of the resource block
  #
  # @param [String] path
  # @return [String]
  # @api public
  attribute :path,
            kind_of: String,
            name_attribute: true

  # Boolean, when `true` the zip file is removed once it has been unzipped, the
  # default value is `false`.
  #
  # @param [TrueClass, FalseClass]
  # @return [TrueClass, FalseClass]
  # @api public
  attribute :remove_after,
            kind_of: [TrueClass, FalseClass],
            default: false

  # Boolean, when `true` forces an overwrite of the files if they already exist
  #
  # @param [TrueClass, FalseClass]
  # @return [TrueClass, FalseClass]
  # @api public
  attribute :overwrite,
            kind_of: [TrueClass, FalseClass],
            default: false

  # Specify the SHA-256 checksum of the file, use to ensure that a specific
  # file is used, if the checksum matches, no download takes place, if it does
  # not match, the file will be re-downloaded accordingly
  #
  # @param [String] path
  # @return [String]
  # @api public
  attribute :checksum,
            kind_of: String,
            default: nil

  # A string or ID that identifies the group owner by user name. If this value
  # is not specified, existing owners will remain unchanged and new owner
  # assignments will use the current user (when necessary).
  #
  # @param [String, Integer] owne
  # @return [String, Integer]
  # @api public
  attribute :owner,
            kind_of: [String, Integer]

  # A string or ID that identifies the group owner by group name, if this value
  # is not specified, existing groups will remain unchanged and new group
  # assignments will use the default POSIX group (if available)
  #
  # @param [String, Integer] group
  # @return [String, Integer]
  # @api public
  attribute :group,
            kind_of: [String, Integer]

  # A quoted string that defines the octal mode for a file. If mode is not
  # specified and if the file already exists, the existing mode on the file is
  # used. If mode is not specified, the file does not exist, and the `:create`
  # action is specified, the chef-client will assume a mask value of `0777` and
  # then apply the umask for the system on which the file will be created to
  # the mask value. For example, if the umask on a system is `022`, the
  # chef-client would use the default value of `0755`.
  #
  # @param [Integer] mode
  # @return [Integer]
  # @api public
  attribute :mode,
            kind_of: Integer

  # Verify the peer using certificates specified in --ca-certificate option.
  # Default: true
  #
  # @param [TrueClass, FalseClass]
  # @return [TrueClass, FalseClass]
  # @api public
  attribute :check_cert,
            kind_of: [TrueClass, FalseClass]

  # The location (URI) of the source file. This value may also specify HTTP
  # (http://), FTP (ftp://), or local (file://) source file locations.
  #
  # @param [String, URI::HTTP] source
  # @return [String, URI::HTTP]
  # @api public
  attribute :source,
            kind_of: [String, URI::HTTP],
            callbacks: { validate_source: ->(source) {
              Chef::Resource::ZipFile.validate_source(source) }},
            required: true

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  def self.validate_source(source)
    source = Array(source).flatten
    raise ArgumentError, "#{resource_name} has an empty source" if source.empty?
    source.each do |src|
      unless absolute_uri?(src)
        raise Exceptions::InvalidRemoteFileURI, "#{src.inspect} is not a "  \
          "valid source parameter for #{resource_name}. source must be an " \
          "absolute URI or an array of URIs."
      end
    end
    true
  end

  def self.absolute_uri?(source)
    source.kind_of?(String) and URI.parse(source).absolute?
  rescue URI::InvalidURIError
    false
  end
end
