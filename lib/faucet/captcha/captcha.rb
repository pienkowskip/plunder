require 'chunky_png'
require 'selenium-webdriver'

require_relative '../utility/logging'
# require_relative '../exceptions'

class Faucet
  module Captcha
    class Captcha
      include Faucet::Utility::Logging

      attr_reader :webdriver

      def initialize(webdriver)
        @webdriver = webdriver
      end

      protected

      def element_screenshot(element)
        image = ChunkyPNG::Image.from_string(webdriver.screenshot_as(:png))
        location = element.location_once_scrolled_into_view
        image.crop!(*[location.x, location.y, element.size.width, element.size.height].map(&:to_i))
      end
    end
  end
end
