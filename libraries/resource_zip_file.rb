# encoding: UTF-8
#
# Cookbook Name:: garcon
# HWRP:: resource_zip_file
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

class Chef::Resource::ZipFile < Chef::Resource::LWRPBase

  identity_attr :path
  provides :zip_file, os: 'linux'

  self.resource_name = :zip_file

  actions :zip, :unzip
  default_action :unzip

  state_attrs :checksum, :owner, :group, :mode

  attribute :path,         kind_of:  String,          name_attribute: true

  attribute :owner,        kind_of: [String, Integer],       default: nil
  attribute :group,        kind_of: [String, Integer],       default: nil
  attribute :mode,         kind_of:  Integer,                default: nil
  attribute :remove_after, kind_of: [TrueClass, FalseClass], default: false
  attribute :overwrite,    kind_of: [TrueClass, FalseClass], default: false
  attribute :checksum,     kind_of:  String,                 default: nil

  attribute :source,       kind_of: [String, URI::HTTP],    required: true,
    callbacks: { validate_source: lambda {
      |source| Chef::Resource::ZipFile.validate_source(source)
    }
  }

  private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

  def self.validate_source(source)
    source = Array(source).flatten
    raise ArgumentError, "#{resource_name} has an empty source" if source.empty?
    source.each do |src|
      unless absolute_uri?(src)
        raise Exceptions::InvalidRemoteFileURI, "#{src.inspect} is not a " \
          "valid `source` parameter for #{resource_name}. `source` must be an " \
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
