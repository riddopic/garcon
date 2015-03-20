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

# Adds `#contains?` and `#shatter` methods to strings
#
class String
  # Search a text file for a matching string
  #
  # @return [TrueClass, FalseClass]
  #   True if the file is present and a match was found, otherwise returns
  #   false if file does not exist and/or does not contain a match
  #
  def contains?(str)
    return false unless ::File.exist?(self)
    ::File.open(self, &:readlines).collect { |l| return true if l.match(str) }
    false
  end

  # Breaks a string up into an array based on a regular expression.
  # Similar to scan, but includes the matches.
  #
  # @example
  #   s = "<p>This<b>is</b>a test.</p>"
  #   s.shatter(/\<.*?\>/)
  #     => [
  #       [0] "<p>",
  #       [1] "This",
  #       [2] "<b>",
  #       [3] "is",
  #       [4] "</b>",
  #       [5] "a test.",
  #       [6] "</p>"
  #     ]
  #
  # @param [Regexp] regex
  #   regular expression for breaking string into array.
  #
  # @return [String]
  def shatter(re)
    r = self.gsub(re) { |s| "\1" + s + "\1" }
    while r[ 0, 1] == "\1";  r[0] = ''; end
    while r[-1, 1] == "\1"; r[-1] = ''; end
    r.split("\1")
  end

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
  def light_gray; colorize(self, "\e[2;37m"); end
  def bright_red; colorize(self, "\e[1;41m"); end
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
