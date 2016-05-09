require 'yaml'
require_relative 'utility/logging'
require_relative 'utility/stats'
require_relative 'captcha/logger'
require_relative 'errors'

class Plunder::Config
  class Fetcher
    def initialize(config, path)
      @config = config
      @path = path.freeze
    end

    def nested(name)
      name = name.to_sym rescue name
      Fetcher.new(@config, @path + [name])
    end

    def method_missing(name, *args)
      nested(name, *args)
    end

    def fetch(*args)
      default = if args.size == 0
                  [false, nil]
                elsif args.size == 1
                  [true, args[0]]
                else
                  raise ArgumentError, 'wrong number of arguments (%d for max 1)' % args.size
                end
      config = @config
      @path.each do |key|
        unless config.is_a?(Hash) && config.include?(key)
          return default[1] if default[0]
          raise Plunder::ConfigError, 'Configuration entry [%s] missing.' % path_to_s
        end
        config = config[key]
      end
      config
    end

    def fetch_i(*args)
      value = fetch(*args)
      begin
        Integer(value)
      rescue ArgumentError
        raise Plunder::ConfigError.new(nil, path_to_s, 'not a valid integer')
      end
    end

    def fetch_f(*args)
      value = fetch(*args)
      begin
        value = Float(value)
        raise ArgumentError, 'not finite number' unless value.finite?
        value
      rescue ArgumentError
        raise Plunder::ConfigError.new(nil, path_to_s, 'not a valid number')
      end
    end

    def exist?
      config = @config
      @path.each do |key|
        return false unless config.is_a?(Hash) && config.include?(key)
        config = config[key]
      end
      true
    end

    private

    def path_to_s
      @path.join('.')
    end
  end

  DEV_MAP = {
      '<stdout>' => STDOUT,
      '<stderr>' => STDERR
  }.freeze

  def initialize(fname)
    begin
      config = deep_symbolize_keys(YAML.load(File.open(fname, 'r')) || {})
    rescue SyntaxError
      raise Plunder::ConfigError, 'Configuration file has invalid syntax. Proper YAML required.'
    end
    @fetcher = Fetcher.new(config, [])
    setup_wrapper('application.logger') { setup_logger }
    setup_wrapper('application.stats_file') { setup_stats }
    setup_wrapper('application.captcha.log') { setup_captcha_logger }
  end

  def method_missing(name, *args)
    @fetcher.public_send(name, *args)
  end

  private

  def setup_logger
    return false unless application.logger.exist?
    file = application.logger.file.fetch
    file = DEV_MAP[file.downcase] if DEV_MAP.include?(file.downcase)
    level = Logger::Severity.const_get(application.logger.level.fetch.upcase.to_sym, false)
    Plunder::Utility::Logging.setup(file, level)
    true
  end

  def setup_stats
    return false unless application.stats_file.exist?
    file = application.stats_file.fetch
    file = DEV_MAP.include?(file.downcase) ? DEV_MAP[file.downcase] : File.open(file, 'a')
    Plunder::Utility::Stats.setup(file)
    true
  end

  def setup_captcha_logger
    Plunder::Captcha::Logging.setup(application.captcha.log.fetch(nil))
    true
  end

  def setup_wrapper(entry_name)
    yield
  rescue Plunder::ConfigError => err
    raise err
  rescue => err
    raise Plunder::ConfigError.new(nil, entry_name, err)
  end

  def deep_symbolize_keys(hash)
    return hash unless hash.is_a?(Hash)
    hash.keys.each do |key|
      hash[(key.to_sym rescue key)] = deep_symbolize_keys(hash.delete(key))
    end
    hash
  end
end