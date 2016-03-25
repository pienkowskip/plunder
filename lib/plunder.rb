require 'capybara/poltergeist'
require 'forwardable'
require 'set'

require_relative 'plunder/version'
require_relative 'plunder/dependency_manager'
require_relative 'plunder/config'
require_relative 'plunder/utility/logging'
require_relative 'plunder/errors'

class Plunder
  include Utility::Logging
  extend Forwardable

  attr_reader :dm
  def_delegators :@dm, :browser, :browser?

  def initialize(config_filename)
    @dm = DependencyManager.new
    @dm.plunder = self
    @dm.config = Config.new(config_filename).freeze
  end

  def setup_browser
    browser_cfg = dm.config.browser
    Capybara.ignore_hidden_elements = true
    Capybara.default_max_wait_time = browser_cfg.fetch(:element_timeout, 2)
    webdriver = browser_cfg.fetch(:webdriver).to_sym
    case webdriver
      when :poltergeist
        options = {
            window_size: [1280, 1024], #SXGA
            js_errors: false,
            phantomjs_logger: File.open('/dev/null', 'a'),
            phantomjs_options: [],
            # logger: STDOUT,
            # phantomjs_logger: STDOUT,
        }
        options[:phantomjs] = File.absolute_path(browser_cfg[:binary_path]) if browser_cfg.include?(:binary_path)
        options[:phantomjs_options].push('--cookies-file=%s' % File.absolute_path(browser_cfg[:cookies_path])) if browser_cfg.include?(:cookies_path)
        options[:timeout] = browser_cfg[:timeout] if browser_cfg.include?(:timeout)
        options[:phantomjs_options].concat([*browser_cfg.fetch(:phantomjs_options, [])])
        Capybara.register_driver(webdriver) do |app|
          driver = Capybara::Poltergeist::Driver.new(app, options)
          driver.add_header('User-Agent', browser_cfg[:user_agent]) if browser_cfg.include?(:user_agent)
          driver
        end
        dm.browser = Capybara::Session.new(webdriver)
      when :webkit
        dm.browser = Capybara::Session.new(webdriver)
      else
        raise ConfigEntryError, 'Unsupported browser [%s] webdriver.' % webdriver
    end
    logger.debug { 'Browser [%s] was set up.' % browser.mode }
    browser
  rescue => exc
    raise ApplicationError, 'Browser setting up error: %s (%s).' % [exc.message, exc.class]
  end

  def restart_browser
    return false unless browser?
    browser.driver.restart
    logger.debug { 'Browser [%s] was restarted.' % browser.mode }
    true
  rescue => exc
    raise ApplicationError, 'Browser restarting error: %s (%s).' % [exc.message, exc.class]
  end

  def quit_browser
    return false unless browser?
    browser_name = browser.mode
    browser.driver.quit
    dm.browser = nil
    logger.debug { 'Browser [%s] was quitted.' % browser_name }
    true
  rescue => exc
    raise ApplicationError, 'Browser quitting error: %s (%s).' % [exc.message, exc.class]
  end

  def diagnostic_dump(exception = nil, path = nil)
    time = Time.new
    if path.nil?
      return false unless dm.config.application[:error_log]
      path = File.join(dm.config.application[:error_log], Time.now.strftime('%FT%H%M%S'))
    end
    if exception
      File.open(path + '.txt', 'a') do |io|
        io.puts("Application error at #{time}.", nil)
        io.puts("Exception: #{exception.message} (#{exception.class}).", nil)
        io.puts('Backtrace:')
        print_exception(exception, io)
      end
    end
    if browser?
      browser.save_screenshot(path + '.png', full: true)
      File.write(path + '.html', browser.html)
    end
    true
  rescue => exc
    raise ApplicationError, 'Cannot save diagnostic dump. Error: %s (%s).' % [exc.message, exc.class]
  end

  private

  def print_exception(exception, io = STDERR)
    exc_to_s = ->(exc) { exc.message == exc.class.name ? exc.class.name : "#{exc.class.name}: #{exc.message}" }
    io.puts(exc_to_s.call(exception))
    exception.backtrace.each { |entry| io.puts("\tfrom #{entry}") }
    exc = exception
    cause_set = Set.new
    while exc.respond_to?(:cause) && exc.cause && cause_set.add?(exc.object_id)
      exc = exc.cause
      io.puts("Caused by: #{exc_to_s.call(exc)}")
      exc.backtrace.each { |entry| io.puts("\tfrom #{entry}") }
    end
  end
end
