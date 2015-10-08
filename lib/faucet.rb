require 'selenium-webdriver'
require 'chunky_png'

require_relative 'faucet/version'
require_relative 'faucet/config'
require_relative 'faucet/utility/logging'

class Faucet
  include Utility::Logging

  attr_reader :config

  def initialize(config_filename)
    @config = Config.new(config_filename).freeze
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
    @webdriver.manage.window.maximize #resize_to(800, 600)
    # logger.info "New browser pid: #{@webdriver.child_process.pid}"
    @webdriver
  end

  def signed_in?
    webdriver.find_element(:id, 'BodyPlaceholder_ClaimPanel')
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def sign_in

  end

  def can_claim?
    webdriver.find_element(id: 'SubmitButton').displayed?
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def claim
    submit_button = webdriver.find_element(id: 'SubmitButton')
    return false unless submit_button.displayed?
    submit_button.click
    sleep 5
    captcha = webdriver.find_element(id: 'adcopy-puzzle-image')
    # puts captcha.location.x, captcha.location.y
    # webdriver.save_screenshot("screenshot_#{Time.new.strftime('%Y%m%dT%H%M%S')}.png")
    # pry self
    element_screenshot(captcha).save("captcha-#{Time.new.strftime('%Y%m%dT%H%M%S')}.png")
    pry self
    # resolve_captcha
    # puts webdriver.find_element(:id, 'CaptchaPopup')
    # puts webdriver.find_element(:id, 'CaptchaPopup').displayed?
    # webdriver.switch_to
    true
  end

  def resolve_captcha
    webdriver.find_element(id: 'adcopy-puzzle-image').click
    message = ''
    puts message
    webdriver.find_element(id: 'adcopy-expanded-response').send_keys(message)
    webdriver.save_screenshot("screenshot_#{Time.new.strftime('%Y%m%dT%H%M%S')}.png")
    webdriver.find_element(id: 'adcopy-expanded-response').send_keys(:return)
    webdriver.find_element(id: 'adcopy_response').send_keys(:return)
    puts webdriver.find_element(id: 'BodyPlaceholder_SuccessfulClaimPanel').displayed?
    # puts webdriver.find_element(id: 'BodyPlaceholder_FailedClaimPanel').displayed?
  end

  def element_screenshot(element)
    image = ChunkyPNG::Image.from_string(webdriver.screenshot_as(:png))
    location = element.location_once_scrolled_into_view
    image.crop!(*[location.x, location.y, element.size.width, element.size.height].map(&:to_i))
  end

  def can_sign_in?
    webdriver.find_element(:id, 'SignInButton')
    webdriver.find_element(:id, 'BodyPlaceholder_PaymentAddressTextbox')
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    false
  end

  def shutdown
    @webdriver.close if @webdriver
    @webdriver = nil
  end
end
