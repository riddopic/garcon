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

module Garcon
  module Provider
    # Library routine that returns an encrypted data bag value for a supplied
    # string. The key used in decrypting the encrypted value should be located
    # at node[:garcon][:secret][:key_path].
    #
    # Note that if node[:garcon][:devmode] is true, then the value of the index
    # parameter is just returned as-is. This means that in developer mode, if a
    # cookbook does this:
    #
    # @example
    #   class Chef
    #     class Recipe
    #       include Garcon::SecretBag
    #     end
    #   end
    #
    #   admin = secret('bag_name', 'RoG+3xqKE23uc')
    #
    # That means admin will be 'RoG+3xqKE23uc'
    #
    # You also can provide a default password value in developer mode, like:
    #
    #   node.set[:garcon][:secret][:passwd] = 'mysql_passwd'
    #   mysql_passwd = secret('passwords', 'eazypass')
    #
    #   The mysql_passwd will == 'eazypass'
    #
    module SecretBag
      include Garcon::Exceptions

      def secret(bag_name, index)
        if node[:garcon][:devmode]
          dev_secret(index)
        else
          case node[:garcon][:databag_type]
          when :encrypted
            encrypted_secret(bag_name, index)
          when :standard
            standard_secret(bag_name, index)
          when :vault
            vault_secret('vault_' + bag_name, index)
          else
            raise InvalidDataBagType
          end
        end
      end

      def encrypted_secret(bag_name, index)
        key_path = node[:garcon][:secret][:key_path]
        Chef::Log.info "Loading encrypted databag #{bag_name}.#{index} " \
                       "using key at #{key_path}"
        secret = Chef::EncryptedDataBagItem.load_secret key_path
        Chef::EncryptedDataBagItem.load(bag_name, index, secret)[index]
      end

      def standard_secret(bag_name, index)
        Chef::Log.info "Loading databag #{bag_name}.#{index}"
        Chef::DataBagItem.load(bag_name, index)[index]
      end

      def vault_secret(bag_name, index)
        begin
          require 'chef-vault'
        rescue LoadError
          Chef::Log.warn "Missing gem 'chef-vault'"
        end
        Chef::Log.info "Loading vault secret #{index} from #{bag_name}"
        ChefVault::Item.load(bag_name, index)[index]
      end

      # Return a password using either data bags or attributes for storage.
      # The storage mechanism used is determined by the
      # `node[:garcon][:use_databags]` attribute.
      #
      # @param [String] type
      #   password type, can be `:user`, `:service`, `:db` or `:token`
      #
      # @param [String] keys
      #   the identifier of the password
      #
      def get_password(type, key)
        unless [:db, :user, :service, :token].include?(type)
          Chef::Log.error "Unsupported type for get_password: #{type}"
          return
        end

        if node[:garcon][:use_databags]
          if type == :token
            secret node[:garcon][:secret][:secrets_data_bag], key
          else
            secret node[:garcon][:secret]["#{type}_passwords_data_bag"], key
          end
        else
          node[:garcon][:secret][key][type]
        end
      end
    end
  end
end
