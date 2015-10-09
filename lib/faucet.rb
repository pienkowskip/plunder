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
    # @webdriver.manage.window.maximize
    @webdriver.manage.window.resize_to(1001, 801)
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
    address_input.send_keys(address)
      sign_in_button.click
      solve_captcha
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
    unless signed_in?
      sign_in
    end
    true
  end

  def solve_captcha
    sleep CAPTCHA_LOAD_DELAY
    captcha_solver.solve
    # webdriver.find_element(id: 'adcopy-puzzle-image').click
    # webdriver.find_element(id: 'adcopy-expanded-response').send_keys(message)
    # webdriver.find_element(id: 'adcopy_response').send_keys(:return)
    # puts webdriver.find_element(id: 'BodyPlaceholder_SuccessfulClaimPanel').displayed?
    # puts webdriver.find_element(id: 'BodyPlaceholder_FailedClaimPanel').displayed?
  end


  def can_sign_in?
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def shutdown
    @webdriver.close if @webdriver
    @webdriver = nil
  end
end
