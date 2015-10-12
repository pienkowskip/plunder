require 'selenium-webdriver'
require 'chunky_png'

require_relative 'faucet/version'
require_relative 'faucet/dependency_manager'
require_relative 'faucet/config'
require_relative 'faucet/utility/logging'

class Faucet
  include Utility::Logging

  CAPTCHA_LOAD_DELAY = 5
  CAPTCHA_SOLVER_RETRIES = 3

  attr_reader :dm, :url, :address

  def initialize(config_filename, url, address)
    @dm = DependencyManager.new
    @dm.faucet = self
    @dm.config = Config.new(config_filename).freeze
    @url, @address = url.to_s.dup.freeze, address.to_s.dup.freeze
  end

  def setup_webdriver
    webdriver = dm.config.browser.fetch(:webdriver).to_sym
    if webdriver == :chrome
      Selenium::WebDriver::Chrome.driver_path = dm.config.browser[:driver_path] if dm.config.browser.include?(:driver_path)
      switches = []
      switches.push("--user-data-dir=#{File.absolute_path(dm.config.browser[:profile_path])}") if dm.config.browser.include?(:profile_path)
      dm.webdriver = Selenium::WebDriver.for(webdriver, switches: switches)
    else
      dm.webdriver = Selenium::WebDriver.for(webdriver)
    end
    dm.webdriver.manage.window.maximize
    # dm.webdriver.manage.window.resize_to(1000, 800)
    dm.webdriver
  end

  def signed_in?
    dm.webdriver.find_element(:id, 'BodyPlaceholder_ClaimPanel')
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def sign_in
    sign_in_button = dm.webdriver.find_element(:id, 'SignInButton')
    raise Selenium::WebDriver::Error::ElementNotVisibleError, 'sign in button not visible' unless sign_in_button.displayed?
    address_input = dm.webdriver.find_element(:id, 'BodyPlaceholder_PaymentAddressTextbox')
    raise Selenium::WebDriver::Error::ElementNotVisibleError, 'address input not visible' unless address_input.displayed?
    address_input.send_keys(address, :return)
    unless signed_in?
      logger.warn { 'Signing in with address %s failure. Unknown reason.' % address }
      raise Faucet::SigningInError, 'signing in failure'
    end
    logger.info { 'Signing in with address %s success.' % address }
    true
  # rescue => error
  #   raise Faucet::SigningInError, "#{error.to_s} (#{error.class.name})"
  end

  def can_claim?
    dm.webdriver.find_element(id: 'SubmitButton').displayed?
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def claim
    dm.webdriver.navigate.to(url)
    sign_in unless signed_in?
    dm.webdriver.find_element(id: 'SubmitButton').click
    solve_captcha
    #TODO: Read result and print log.
    true
  end

  def solve_captcha
    sleep CAPTCHA_LOAD_DELAY
    dm.captcha_solver.solve
    # webdriver.find_element(id: 'adcopy-link-refresh')
  end

  def shutdown
    dm.webdriver.close if dm.webdriver?
    dm.webdriver = nil
  end
end
