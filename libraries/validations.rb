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

require 'ipaddr'
require 'openssl'
require 'base64'
require 'securerandom'

# Helper methods for cookbook.
#
module Garcon
  # A set of helper methods shared by all resources and providers.
  #
  module Validations

    # Matches on a string.
    STRING_VALID_REGEX = /\A[^\\\/\:\*\?\<\>\|]+\z/

    # Matches on a file mode.
    FILE_MODE_VALID_REGEX = /^0?\d{3,4}$/

    # Matches on a MD5/SHA-1/256 checksum.
    CHECKSUM_VALID_REGEX = /^[0-9a-f]{32}$|^[a-zA-Z0-9]{40,64}$/

    # Matches on a URL/URI with a archive file link.
    URL_ARCH_VALID_REGEX = /^(file|http|https?):\/\/.*(gz|tar.gz|tgz|bin|zip)$/

    # Matches on a FQDN like name (does not validate FQDN).
    FQDN_VALID_REGEX = /^(?:(?:[0-9a-zA-Z_\-]+)\.){2,}(?:[0-9a-zA-Z_\-]+)$/

    # Matches on a valid IPV4 address.
    IPV4_VALID_REGEX = /\b(25[0-5]|2[0-4]\d|1\d\d|
                        [1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}\b/

    # Matches on port ranges 0 to 1023.
    VALID_PORTS_REGEX = /^(102[0-3]|10[0-1]\d|[1-9][0-9]{0,2}|0)$/

    # Matches on any port from 0 to 65_535.
    PORTS_ALL_VALID_REGEX = /^(6553[0-5]|655[0-2]\d|65[0-4]\d\d|6[0-4]\d{3}|
                             [1-5]\d{4}|[1-9]\d{0,3}|0)$/

    # def valid_fqdn(fqdn)
    #   unless value =~ FQDN_VALID_REGEX
    #     raise ArgumentError, "`#{fqdn}` is not a valid FQDN."
    #   end
    #   value
    # end
    #
    # # Boolean, true if port number is within range, otherwise raises a
    # # Validation::InvalidPort exception
    # #
    # # @param [Integer] port
    # # @param [Range<Integer>] range
    # #
    # # @return [Trueclass]
    # #
    # # @raise [Validation::InvalidPort]
    # #
    # def valid_port?(port, range)
    #   (range === port) ? true : (fail Validation::InvalidPort, port, range)
    # end
    #
    # def validate_string(name, value, values)
    #   unless values.include? value
    #     raise RangeError, "Invalid value for '#{name}', accepted values are '#{values.join('\', \'')}'"
    #   end
    #   value
    # end
    #
    # def validate_http_uri(name, value)
    #   uri = URI value
    #   uri = URI 'http://' + value unless uri.scheme
    #   unless ['http', 'https'].include? uri.scheme.to_s.downcase
    #     raise ArgumentError, "Invalid scheme for '#{name}' URI, accepted schemes are 'http' and 'https'"
    #   end
    #   uri
    # end
    #
    # def validate_boolean(name, value)
    #   unless value.is_a?(TrueClass) || value.is_a?(FalseClass)
    #     raise TypeError, "Invalid value for '#{name}' expecting 'True' or 'False'"
    #   end
    #   value
    # end
    #
    # def validate_time(name, value)
    #   unless value =~ /^([01]?[0-9]|2[0-3])(\:[0-5][0-9]){1,2}$/
    #     raise ArgumentError, "Invalid value for '#{name}', format is: 'HH:MM:SS'"
    #   end
    #   value
    # end
    #
    # def validate_integer(name, value, min, max)
    #   i = value.to_i
    #   unless i >= min && i <= max && value.to_s =~ /^\d+$/
    #     raise ArgumentError, "Invalid value for '#{name}', value must be between #{min} and #{max}"
    #   end
    #   i
    # end
    # def check_ipv4
    #     lambda { |ip|
    #         if ip =~ /^([0-9]{1,3}\.){3}[0-9]{1,3}$/
    #             true
    #         else
    #             false
    #         end
    #     }
    # end
    #
    # def check_ipv4_or_nil
    #     lambda { |ip|
    #         ip.kind_of?(NilClass) ? true : check_ipv4().call( ip )
    #     }
    # end
    #
    # def valid_ttl
    #     lambda { |ttl| ( ttl.kind_of?( String ) and ( ttl =~ /^[0-9]+[ms]$/ ) ) ? true : false }
    # end
    #
    # def valid_ttl_key key
    #     lambda { |hash|
    #         return true unless hash.has_key? key
    #         return valid_ttl.call(hash[key])
    #     }
    # end
    #
    # def true_false
    #     lambda { |val| [ TrueClass, FalseClass ].include? val.class }
    # end
    #
    # def true_false_key key
    #     lambda { |hash|
    #         return true unless hash.has_key?( key )
    #         return true_false.call( hash[key] )
    #     }
    # end
    #
    # def valid_range min, max
    #     lambda { | val|
    #         val >= min and val <= max
    #     }
    # end
    #
    # def valid_port min=0, max=65535
    #     valid_range(min, max)
    # end
    #
    # def key_valid_port key, min, max
    #     lambda { |port|
    #         return true unless port.has_key? key
    #         return valid_port(min, max).call port[key]
    #     }
    # end

  end
end
