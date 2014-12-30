# encoding: UTF-8
#
# Author: Stefano Harding <riddopic@gmail.com>
#
# Copyright (C) 2012-2014 Stefano Harding
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

require 'logger'
require 'time'

module Garcon
  module Logging
    @loggers ||= {}

    def demodulize(class_name_in_module)
      class_name_in_module.to_s.sub(/^.*::/, '')
    end

    class << self

      class NoLogger < Logger
        def initialize(*args)
        end

        def add(*args, &block)
        end
      end

      def demodulize(class_name_in_module)
        class_name_in_module.to_s.sub(/^.*::/, '')
      end

      def log(prefix)
        @loggers[prefix] ||= logger_for(prefix)
      end

      def logger_for(prefix)

        log = logger
        log.progname = prefix
        log.formatter = Garcon::Formatter.new
        log.formatter.datetime_format = '%F %T'
        log.level = eval(log_level)
        log
      end

      def log=(log)
        @log = log
      end

      def logger
        Garcon.configuration.logging ? Logger.new($stdout) : NoLogger.new
      end

      def log_level
        "Logger::#{Garcon.configuration.level.to_s.upcase}"
      end
    end

    def self.included(base)
      class << base
        def log
          prefix = self.class == Class ? self.to_s : self.class.to_s
          Garcon::Logging.log(demodulize(prefix))
        end
      end
    end

    def log
      prefix = self.class == Class ? self.to_s : self.class.to_s
      Garcon::Logging.log(demodulize(prefix))
    end
  end

  class Formatter < Logger::Formatter
    attr_accessor :datetime_format

    def initialize
      @datetime_format = nil
      super
    end

    def call(severity, time, progname, msg)
      format % [
        format_datetime(time).BLUE,
        severity.GREEN,
        msg2str(msg).strip.ORANGE
      ]
    end

    private #   P R O P R I E T À   P R I V A T A   Vietato L'accesso

    def format
      "[%s] %5s: %s\n"
    end

    def format_datetime(time)
      if @datetime_format.nil?
        time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
      else
        time.strftime(@datetime_format)
      end
    end
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
