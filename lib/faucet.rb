require 'capybara/poltergeist'
require 'chunky_png'

require_relative 'faucet/version'
require_relative 'faucet/dependency_manager'
require_relative 'faucet/config'
require_relative 'faucet/utility/logging'

class Faucet
  include Utility::Logging
  extend Forwardable

  CAPTCHA_SOLVER_RETRIES = 3

  attr_reader :dm
  def_delegators :@dm, :browser, :browser?

  def initialize(config_filename)
    @dm = DependencyManager.new
    @dm.faucet = self
    @dm.config = Config.new(config_filename).freeze
  end

  def setup_browser
    browser_cfg = dm.config.browser
    Capybara.ignore_hidden_elements = true
    case browser_cfg.fetch(:webdriver).to_sym
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
        Capybara.register_driver(:poltergeist) do |app|
          driver = Capybara::Poltergeist::Driver.new(app, options)
          driver.add_header('User-Agent', browser_cfg[:user_agent]) if browser_cfg.include?(:user_agent)
          driver
        end
        dm.browser = Capybara::Session.new(:poltergeist)
      when :webkit
        dm.browser = Capybara::Session.new(:webkit)
      else
        raise ConfigEntryError, 'unsupported browser webdriver'
    end
    logger.debug { 'Browser [%s] was set up.' % browser.mode }
    browser
  end

  def signed_in?(address)
    browser.find(:id, 'BodyPlaceholder_ClaimPanel').find(:id, 'SignedInPaymentAddress').value == address
  rescue Capybara::ElementNotFound
    false
  end

  def sign_in(address)
    browser.driver.set_cookie('user', "PaymentAddress=#{address}")
    browser.visit(browser.current_url)
    unless signed_in?(address)
      logger.warn { 'Signing in as address [%s] failure. Unknown reason.' % address }
      raise Faucet::SigningInError, 'signing in failure'
    end
    logger.info { 'Signing in as address [%s] success.' % address }
    true
  end

  def claim(url, address)
    browser.visit(url)
    logger.debug { 'Claiming URL [%s] loaded.' % url }
    unless signed_in?(address)
      logger.debug { 'Not signed in as address [%s].' % address }
      sign_in(address)
    end
    dm.sleep_rand(1.0..3.0)
    browser.find(:id, 'SubmitButton').click
    logger.debug { 'Beginning to perform claim for [%s].' % address }
    solve_captcha
    # browser.save_screenshot('claim-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S'), full: true)
    # TODO: Read result and print log.
    true
  end

  def solve_captcha
    dm.sleep_rand(4.0..6.0)
    dm.captcha_solver.solve
    # webdriver.find_element(id: 'adcopy-link-refresh')
  end
end
