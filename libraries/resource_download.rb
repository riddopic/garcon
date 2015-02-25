# encoding: UTF-8
#
# Cookbook Name:: garcon
# Resources:: download
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

class Chef::Resource::Download < Chef::Resource
  include Garcon

  # The module where Chef should look for providers for this resource
  #
  # @param [Module] arg
  #   the module containing providers for this resource
  # @return [Module]
  #   the module containing providers for this resource
  # @api private
  provider_base Chef::Provider::Download

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
  # @return [Chef::Resource::Download]
  #   the class of the Chef::Resource based on the short name
  # @api private
  provides :download, os: 'linux'

  # Set or return the list of `state attributes` implemented by the Resource,
  # these are attributes that describe the desired state of the system
  #
  # @return [Chef::Resource::Download]
  # @api private
  state_attrs :checksum, :owner, :group, :mode

  # Adds actions to the list of valid actions for this resource
  #
  # @return [Chef::Resource::Download]
  # @api public
  actions :create, :create_if_missing, :delete, :touch

  # Sets the default action
  #
  # @return [undefined]
  # @api private
  default_action :create

  # @!attribute [w] exists
  #   @return [TrueClass, FalseClass] true if resource exists, otherwise false
  attr_accessor :exists

  def initialize(name, run_context = nil)
    super
    @path = name
    @resource_name = :download
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

  # Specify a directory where files should be downloaded, if you specify both
  # directory and a full path in the file name they will be combined.
  #
  # @param [String] directory
  # @return [String]
  # @api public
  attribute :directory,
            kind_of: String,
            default: nil

  # The number of backups to be kept, set to `false` to prevent backups from
  # being kept, default value is `5`
  #
  # @param [Integer, FalseClass] backup
  # @return [Integer, FalseClass]
  # @api public
  attribute :backup,
            kind_of: [Integer, FalseClass],
            default: 5

  # Specify the SHA-256 checksum of the file, use to ensure that a specific
  # file is used, if the checksum matches, no download takes place, if it does
  # not match, the file will be re-downloaded accordingly
  #
  # @param [String] checksum
  # @return [String]
  # @api public
  attribute :checksum,
            kind_of: String,
            default: nil

  # Download a file using N connections, if more than N URIs are given, first N
  # URIs are used and remaining URIs are used for backup, if less than N URIs
  # are given, those URIs are used more than once so that N connections total
  # are made simultaneously. the default is `5`
  #
  # @param [Integer] split_size
  # @return [Integer]
  # @api public
  attribute :split_size,
            kind_of: Integer,
            default: 5

  # The maximum number of connections to one server for each download, the
  # default is `5`
  #
  # @param [Integer] connections
  # @return [Integer]
  # @api public
  attribute :connections,
            kind_of: Integer,
            default: 5

  # A string or ID that identifies the group owner by user name. If this value
  # is not specified, existing owners will remain unchanged and new owner
  # assignments will use the current user (when necessary).
  #
  # @param [String, Integer] owner
  # @return [String, Integer]
  # @api public
  attribute :owner,
            kind_of: [String, Integer],
            default: nil

  # A string or ID that identifies the group owner by group name, if this value
  # is not specified, existing groups will remain unchanged and new group
  # assignments will use the default POSIX group (if available)
  #
  # @param [String, Integer] group
  # @return [String, Integer]
  # @api public
  attribute :group,
            kind_of: [String, Integer],
            default: nil

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
            kind_of: Integer,
            default: nil

  # Verify the peer using certificates specified in --ca-certificate option.
  # Default: true
  #
  # @param [TrueClass, FalseClass]
  # @return [TrueClass, FalseClass]
  # @api public
  attribute :check_cert,
            kind_of: [TrueClass, FalseClass]

  # Append HEADER to HTTP request header.
  #
  # @param [String] header
  # @return [String]
  # @api public
  attribute :header,
            kind_of: String

  # The location (URI) of the source file. This value may also specify HTTP
  # (http://), FTP (ftp://), or local (file://) source file locations.
  #
  # @param [String, URI::HTTP] source
  # @return [String, URI::HTTP]
  # @api public
  attribute :source,
            kind_of: [String, URI::HTTP],
            callbacks: { source: ->(source) { validate_source(source) }},
            required: true

  # @return [TrueClass, FalseClass] if the resource exists.
  def exists?
    !!@exists
  end
end
