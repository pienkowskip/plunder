require 'selenium-webdriver'
require 'chunky_png'

require_relative 'faucet/version'
require_relative 'faucet/config'
require_relative 'faucet/utility/logging'
require_relative 'faucet/captcha/solver'

class Faucet
  include Utility::Logging

  CAPTCHA_LOAD_DELAY = 5
  CAPTCHA_SOLVER_RETRIES = 3

  attr_reader :config, :url, :address

  def initialize(config_filename, url, address)
    @config = Config.new(config_filename).freeze
    @url, @address = url.to_s.dup.freeze, address.to_s.dup.freeze
  end

  def webdriver
    return @webdriver unless @webdriver.nil?
    webdriver = @config.browser.fetch(:webdriver).to_sym
    if webdriver == :chrome
      Selenium::WebDriver::Chrome.driver_path = @config.browser[:driver_path] if @config.browser.include?(:driver_path)
      switches = []
      switches.push("--user-data-dir=#{File.absolute_path(@config.browser[:profile_path])}") if @config.browser.include?(:profile_path)
      @webdriver = Selenium::WebDriver.for(webdriver, switches: switches)
    else
      @webdriver = Selenium::WebDriver.for(webdriver)
    end
    @webdriver.manage.window.maximize
    # @webdriver.manage.window.resize_to(1000, 800)
    @webdriver
  end

  def captcha_solver
    return @captcha_solver if @captcha_solver
    @captcha_solver = Captcha::Solver.new(webdriver)
  end

  def signed_in?
    webdriver.find_element(:id, 'BodyPlaceholder_ClaimPanel')
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def sign_in
    sign_in_button = webdriver.find_element(:id, 'SignInButton')
    raise Selenium::WebDriver::Error::ElementNotVisibleError, 'sign in button not visible' unless sign_in_button.displayed?
    address_input = webdriver.find_element(:id, 'BodyPlaceholder_PaymentAddressTextbox')
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
    webdriver.find_element(id: 'SubmitButton').displayed?
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def claim
    webdriver.navigate.to(url)
    sign_in unless signed_in?
    webdriver.find_element(id: 'SubmitButton').click
    solve_captcha
    #TODO: Read result and print log.
    true
  end

  def solve_captcha
    sleep CAPTCHA_LOAD_DELAY
    captcha_solver.solve
    # webdriver.find_element(id: 'adcopy-link-refresh')

    # webdriver.find_element(id: 'adcopy_response').send_keys(:return)
    # puts webdriver.find_element(id: 'BodyPlaceholder_SuccessfulClaimPanel').displayed?
    # puts webdriver.find_element(id: 'BodyPlaceholder_FailedClaimPanel').displayed?
  end

  def shutdown
    @webdriver.close if @webdriver
    @webdriver = nil
  end
end
