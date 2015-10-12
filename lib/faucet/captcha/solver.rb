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

      attr_reader :dm, :solvers

      def initialize(dm)
        @dm = dm
        @solvers = [
            Faucet::Captcha::Sponsored.new(dm),
            Faucet::Captcha::Canvas.new(dm),
            Faucet::Captcha::Image.new(dm)
        ]
      end

      def solve
        popup = dm.webdriver.find_element(id: 'CaptchaPopup')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha popup not visible' unless popup.displayed?
        captcha = popup.find_element(id: 'adcopy-puzzle-image-image')
        raise Selenium::WebDriver::Error::ElementNotVisibleError, 'captcha element not visible' unless captcha.displayed?
        answer = nil
        solved_by = nil
        @solvers.each do |solver|
          answer = solver.solve(captcha)
          if answer
            solved_by = solver
            logger.debug { 'Captcha solved. Used solver: %s.' % solver.class.name }
            break
          end
        end
        unless answer
          logger.debug { 'Captcha type not recognized.' }
          raise Faucet::UnsolvableCaptchaError, 'cannot recognize captcha type'
        end
        dm.webdriver.find_element(id: 'adcopy_response').send_keys(answer, :return)
        if result_visible?('BodyPlaceholder_SuccessfulClaimPanel')
          logger.info { 'Captcha properly solved. Answer accepted.' }
          # solved_by.answer_accepted
          return true
        end
        if result_visible?('BodyPlaceholder_FailedClaimPanel')
          logger.warn { 'Captcha improperly solved. Answer rejected.' }
          # solved_by.answer_rejected
          return false # A moze wyjatek?
        end
        raise Selenium::WebDriver::Error::NoSuchElementError, 'captcha correctness (visible) element not found'
      end

      private

      def result_visible?(id)
        dm.webdriver.find_element(id: id).displayed?
      rescue Selenium::WebDriver::Error::NoSuchElementError
        return false
      end
    end
  end
end
