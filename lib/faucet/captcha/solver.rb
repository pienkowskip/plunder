require_relative 'classic'
require_relative 'sponsored'
require_relative '../utility/logging'
require_relative '../exceptions'

require 'chunky_png'
require 'selenium-webdriver'

class Faucet
  module Captcha
    class Solver
      include Faucet::Utility::Logging

      attr_reader :webdriver

      def initialize(webdriver)
        @webdriver = webdriver
      end

      def solve
        popup = webdriver.find_element(id: 'CaptchaPopup')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha popup not visible' unless popup.displayed?
        captcha = popup.find_element(id: 'adcopy-puzzle-image')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha element not visible' unless captcha.displayed?
        captcha_image = element_screenshot(captcha)
        logger.debug { 'Captcha image fetched.' }
        captcha_image.save('captcha-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S'))
        solver = detect_captcha_solver(captcha_image)
        if solver
          logger.debug { 'Captcha type recognized: %s.' % solver.class.name }
        else
          logger.debug { 'Captcha type not recognized.' % solver.class.name }
          raise Faucet::UnsolvableCaptchaError, 'cannot recognize captcha type'
        end
        false
      end

      def detect_captcha_solver(image)
        [Faucet::Captcha::Sponsored, Faucet::Captcha::Classic].each do |klass|
          solver = klass.recognize(image)
          return solver if solver
        end
        nil
      end

      def element_screenshot(element)
        image = ChunkyPNG::Image.from_string(webdriver.screenshot_as(:png))
        location = element.location_once_scrolled_into_view
        image.crop!(*[location.x, location.y, element.size.width, element.size.height].map(&:to_i))
      end
    end
  end
end
