require 'chunky_png'
require 'selenium-webdriver'

require_relative 'sponsored'
require_relative 'canvas'
require_relative 'image'
require_relative '../utility/logging'
require_relative '../exceptions'

class Faucet
  module Captcha
    class Solver
      include Faucet::Utility::Logging

      attr_reader :webdriver, :solvers

      def initialize(webdriver)
        @webdriver = webdriver
        @solvers = [
            Faucet::Captcha::Sponsored.new(webdriver),
            Faucet::Captcha::Canvas.new(webdriver),
            Faucet::Captcha::Image.new(webdriver)
        ]
      end

      def solve
        popup = webdriver.find_element(id: 'CaptchaPopup')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha popup not visible' unless popup.displayed?
        captcha = popup.find_element(id: 'adcopy-puzzle-image-image')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha element not visible' unless captcha.displayed?
        answer = nil
        solved_by = nil
        @solvers.each do |solver|
          answer = solver.solve(captcha)
          if answer
            solved_by = solver
            logger.debug { 'Captcha solved. Used solve: %s.' % solver.class.name }
            break
          end
        end
        unless answer
          logger.debug { 'Captcha type not recognized.' }
          raise Faucet::UnsolvableCaptchaError, 'cannot recognize captcha type'
        end
        #TODO: Pass answer and submit.
        #TODO: Feedback solver with success/failure.
        answer
      end
    end
  end
end
