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

require 'shellwords'

module Shellwords

  module_function

  # Escape special characters used in most unix shells
  # to use it, eg. with system().
  #
  # This differs from Ruby's #escape in that it does not
  # escape shell variables, e.g. $0.
  def alt_escape(cmdline)
    cmdline.gsub(/([\\\t\| &`<>)('"])/) { |s| '\\' << s }
  end

  unless method_defined?(:escape)
    def escape(cmdline)
      cmdline.gsub(/([\\\t\| &`<>)('"])\$/) { |s| '\\' << s }
    end
  end

  # Escape special character used in DOS-based shells.
  #
  # TODO: How to integrate with rest of system?
  # 1. Use platform condition?
  # 2. Use separate dos_xxx methods?
  # 3. Put in separate PowerShellwords module?
  #
  def dos_escape(cmdline)
    '"' + cmdline.gsub(/\\(?=\\*\")/, "\\\\\\").
                  gsub(/\"/, "\\\"").
                  gsub(/\\$/, "\\\\\\").
                  gsub("%", "%%") + '"'
  end

  # The coolest little arguments parser in all of Rubyland.
  #
  def parse(argv, opts)
    argv = (String === argv ? shellwords(argv) : argv.to_a.dup)
    args = []
    while argv.any?
      item = argv.shift
      flag = opts[item]
      if flag
        arity = [flag.arity, 0].max
        if argv.size < arity
          raise ArgumentError
        end
        flag.call(*argv.shift(arity))
      else
        args << item
      end
    end
    args
  end
  alias_method :run, :parse
end

class Array
  # Convert an array into command line parameters. The array is accepted in the
  # format of Ruby method arguments --ie. [arg1, arg2, ..., hash]
  #
  def shellwords
    opts, args = *flatten.partition{ |e| Hash === e }
    opts = opts.inject({}){ |m,h| m.update(h); m }
    opts.shellwords + args
  end

  def shelljoin
    Shellwords.shelljoin(shellwords)
  end
end

class Hash
  def shellwords
    argv = []
    each do |f,v|
      m = f.to_s.size == 1 ? '-' : '--'
      case v
      when false, nil
      when Array
        v.each do |e|
          argv << %[#{m}#{f}="#{e}"]
        end
      when true
        argv << %[#{m}#{f}]
      else
        argv << %[#{m}#{f}="#{v}"]
      end
    end
    argv
  end

  def shelljoin
    shellwords.shelljoin
  end
end
