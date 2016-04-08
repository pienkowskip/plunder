require_relative '../../illegal_state_error'

class Plunder
  module Captcha
    class Logger
      attr_reader :image, :cropped_image, :dirname

      def initialize(dirname)
        if dirname.nil?
          @dirname = nil
        else
          raise ArgumentError, 'Captcha logger directory [%s] not exists or not writable.' % dirname unless Dir.exists?(dirname) && File.writable?(dirname)
          @dirname = dirname.dup.freeze
        end
        clear_entry
      end

      def image=(image)
        state_check
        @image = image
      end

      def cropped_image=(image)
        state_check
        @cropped_image = image
      end

      def []=(key, value)
        state_check
        @values[key.to_s] = value
      end

      [:[], :keys, :values].each do |name|
        define_method(name) do |*args|
          state_check
          @values.public_send(name, *args)
        end
      end

      def open_entry
        clear_entry
        @timestamp = Time.now.freeze
        @values = {}
        self
      end

      def log_entry
        state_check
        return clear_entry if dirname.nil?
        ts_str = @timestamp.strftime('%FT%T.%6N')
        raise IllegalStateError, 'No captcha image provided for logging.' unless @image
        File.write(File.join(dirname, '%s.png' % ts_str), @image)
        if @cropped_image
          path = File.join(dirname, '%s-cropped.png' % ts_str)
          @cropped_image.respond_to?(:save) ? @cropped_image.save(path) : File.write(path, @cropped_image)
        end
        File.open(File.join(dirname, '%s.txt' % ts_str), 'w') do |file|
          @values.sort.each { |key, value| file.puts '%s: %s' % [key, value] }
        end unless @values.empty?
        clear_entry
      end

      def clear_entry
        @timestamp, @image, @cropped_image = nil, nil, nil
        @values = {}
        self
      end

      def has_entry?
        !@timestamp.nil?
      end

      private

      def state_check
        raise IllegalStateError, 'Empty captcha log entry. Open one to operate.' unless has_entry?
      end
    end

    module Logging
      def captcha_logger
        Plunder::Captcha::Logging.logger
      end

      def self.setup(dirname)
        @captcha_logger = Plunder::Captcha::Logger.new(dirname)
        self
      end

      def self.logger
        @captcha_logger
      end
    end
  end
end