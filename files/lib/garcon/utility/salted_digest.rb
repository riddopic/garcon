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

require 'digest'
require_relative '../core_ext/random'

module Digest

  module Instance
    def salted_digest(str='', salt=:auto)
      if salt == :auto
        salt = String.random_binary(digest_length)
      end
      digest(str + salt) + salt
    end

    def salted_hexdigest(str, salt)
      Digest.hexencode(salted_digest(str, salt))
    end

    def salted_base64digest(str, salt)
      [salted_digest(str, salt)].pack('m0')
    end
  end

  class Class
    def self.salted_digest(str, salt=:auto, *args)
      new(*args).salted_digest(str, salt)
    end

    def self.salted_hexdigest(str, salt=:auto, *args)
      new(*args).salted_hexdigest(str, salt)
    end

    def self.salted_base64digest(str, salt=:auto, *args)
      new(*args).salted_base64digest(str, salt)
    end
  end
end
