require 'capybara/poltergeist'
require 'forwardable'

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
    # Capybara.default_max_wait_time = 3
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

  def reset_browser
  end

  def quit_browser
    return unless browser?
    browser.driver.quit
    dm.browser = nil
  rescue => exc
    raise ApplicationError, 'Browser quitting error: %s (%s).' % [exc.message, exc.class]
  end
end
