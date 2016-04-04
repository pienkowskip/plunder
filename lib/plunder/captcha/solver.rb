require 'chunky_png'
require 'timeout'

require_relative 'sponsored'
require_relative 'canvas'
require_relative 'image'
require_relative '../utility/logging'
require_relative '../errors'
require_relative '../../kernel'

class Plunder
  module Captcha
    class Solver
      include Plunder::Utility::Logging
      extend Forwardable

      IMAGE_CAPTCHA_REFRESHES = 3

      attr_reader :dm, :solvers
      def_delegators :@dm, :browser

      def initialize(dm)
        @dm = dm
        @solvers = [
            Plunder::Captcha::Sponsored.new(dm),
            Plunder::Captcha::Canvas.new(dm),
            Plunder::Captcha::Image.new(dm)
        ]
      end

      def solve
        popup = browser.find(:id, 'CaptchaPopup')
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        IMAGE_CAPTCHA_REFRESHES.times do
          break unless captcha.tag_name == 'img'
          logger.debug { 'Provided captcha is an image. Refreshing.' }
          popup.find(:id, 'adcopy-link-refresh').click
          dm.random.sleep(2.0..4.0)
          captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        end
        captcha_image_blob = Base64.decode64(browser.driver.render_base64(:png, selector: '#adcopy-puzzle-image-image'))
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
          logger.warn { 'Captcha type not recognized.' }
          raise Plunder::CaptchaError, 'Captcha type not recognized.'
        end
        answer.force_encoding(Encoding::UTF_8)
        logger.debug { 'Submitting captcha answer [%s].' % answer }
        popup.find(:id, 'adcopy_response').send_keys(answer, :Enter)
        inline_rescue(Timeout::Error) do
          Timeout.timeout(dm.config.browser.fetch(:timeout, 30) / 3.0) do
            nil until has_result?('BodyPlaceholder_SuccessfulClaimPanel') || has_result?('BodyPlaceholder_FailedClaimPanel')
          end
        end
        if has_result?('BodyPlaceholder_SuccessfulClaimPanel')
          logger.info { 'Captcha correctly solved. Answer [%s] accepted.' % answer }
          solved_by.answer_accepted
          return true
        end
        if has_result?('BodyPlaceholder_FailedClaimPanel')
          logger.warn { 'Captcha incorrectly solved. Answer [%s] rejected.' % answer }
          begin
            File.write(File.join(dm.config.application[:error_log], 'captcha-rejected_answer-%s.png' % Time.now.strftime('%FT%H%M%S')),
                       captcha_image_blob) if dm.config.application[:error_log]
          rescue => exc
            raise Plunder::ApplicationError, 'Cannot save image of captcha of rejected answer. Error: %s (%s).' % [exc.message, exc.class]
          end
          solved_by.answer_rejected
          raise Plunder::CaptchaError, 'Captcha incorrectly solved. Answer [%s] rejected.' % answer
        end
        raise Plunder::AfterClaimError, 'Unable to find captcha answer correctness element.'
      end

      private

      def has_result?(id)
        browser.find(:id, id)
        true
      rescue Capybara::ElementNotFound
        return false
      end
    end
  end
end
