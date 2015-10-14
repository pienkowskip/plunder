require 'chunky_png'

require_relative 'sponsored'
require_relative 'canvas'
require_relative 'image'
require_relative '../utility/logging'
require_relative '../exceptions'

class Faucet
  module Captcha
    class Solver
      include Faucet::Utility::Logging
      extend Forwardable

      IMAGE_CAPTCHA_REFRESHES = 3

      attr_reader :dm, :solvers
      def_delegators :@dm, :browser

      def initialize(dm)
        @dm = dm
        @solvers = [
            Faucet::Captcha::Sponsored.new(dm),
            Faucet::Captcha::Canvas.new(dm),
            Faucet::Captcha::Image.new(dm)
        ]
      end

      def solve
        popup = browser.find(:id, 'CaptchaPopup')
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        IMAGE_CAPTCHA_REFRESHES.times do
          break unless captcha.tag_name == 'img'
          logger.debug { 'Provided captcha is an image. Refreshing.' }
          popup.find(:id, 'adcopy-link-refresh').click
          dm.sleep_rand(1.0..3.0)
          captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        end
        answer = nil
        solved_by = nil
        @solvers.each do |solver|
          answer = solver.solve(captcha)
          if answer
            solved_by = solver
            logger.debug { 'Captcha solved by [%s] solver.' % solved_by.class.name }
            break
          end
        end
        unless answer
          logger.debug { 'Captcha type not recognized.' }
          raise Faucet::UnsolvableCaptchaError, 'cannot recognize captcha type'
        end
        browser.find(:id, 'adcopy_response').send_keys(answer, :Enter)
        dm.sleep_rand(1.0..3.0)
        if has_result?('BodyPlaceholder_SuccessfulClaimPanel')
          logger.info { 'Captcha properly solved. Answer [%s] accepted.' % answer }
          # solved_by.answer_accepted
          return true
        end
        if has_result?('BodyPlaceholder_FailedClaimPanel')
          logger.warn { 'Captcha improperly solved. Answer [%s] rejected.' % answer }
          # solved_by.answer_rejected
          return false # A moze wyjatek?
        end
        raise Capybara::ElementNotFound, 'unable to find captcha correctness element'
      end

      private

      def has_result?(id)
        browser.find(:id, id)
      rescue Capybara::ElementNotFound
        return false
      end
    end
  end
end
