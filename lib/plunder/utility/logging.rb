require 'logger'
require_relative '../../illegal_state_error'

module Plunder::Utility
  module Logging
    class Timer
      SIMPLE_FORMAT = '%<msg>s (in %<time>.3fs)'.freeze
      COLOR_FORMAT = "\e[1m\e[36m[%<time>.3fs]\e[0m %<msg>s".freeze
      attr_reader :duration

      def start
        raise IllegalStateError, 'Timer not finished' unless @start.nil?
        @duration = nil
        @start = Time.now
        self
      end

      def finish
        raise IllegalStateError, 'Timer not started' if @start.nil?
        @duration = Time.now - @start
        @start = nil
        self
      end

      def enhance(msg, color = true)
        raise IllegalStateError, 'Timer not finished' if @duration.nil?
        (color ? COLOR_FORMAT : SIMPLE_FORMAT) % {msg: msg.to_s, time: @duration}
      end
    end

    def logger
      return @logger unless @logger.nil?
      @logger = Plunder::Utility::Logging.logger_for(self.class.name)
    end

    @loggers = {}
    @logdev = STDOUT
    @level = Logger::DEBUG

    def self.setup(logdev, level)
      @logdev, @level = logdev, level
      self
    end

    def self.logger_for(classname)
      return @loggers[classname] if @loggers.include? classname
      logger = Logger.new(@logdev)
      logger.progname = classname
      logger.level = @level
      @loggers[classname] = logger
    end
  end
end