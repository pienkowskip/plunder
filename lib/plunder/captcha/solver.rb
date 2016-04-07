require 'timeout'
require 'base64'

require_relative 'sponsored'
require_relative 'canvas'
require_relative 'image'
require_relative 'image_decoder/ocr'
require_relative 'image_decoder/external_service'
require_relative '../utility/logging'
require_relative '../utility/stats'
require_relative '../errors'
require_relative '../../kernel'

class Plunder
  module Captcha
    class Solver
      include Plunder::Utility::Logging
      include Plunder::Utility::Stats
      extend Forwardable

      IMAGE_CAPTCHA_REFRESHES = 3

      attr_reader :dm, :solvers
      def_delegators :@dm, :browser

      def initialize(dm)
        @dm = dm
        ocr_decoder = Plunder::Captcha::ImageDecoder::OCR.new(dm)
        external_service_decoder = Plunder::Captcha::ImageDecoder::ExternalService.new(dm.two_captcha_client)
        sponsored_solver = Plunder::Captcha::Sponsored.new(dm)
        @ocr_solvers = [sponsored_solver] + [Plunder::Captcha::Canvas, Plunder::Captcha::Image].map { |klass| klass.new(dm, ocr_decoder) }
        @external_service_solvers = [sponsored_solver] + [Plunder::Captcha::Canvas, Plunder::Captcha::Image].map { |klass| klass.new(dm, external_service_decoder) }
      end

      def solve_captcha
        popup = browser.find(:id, 'CaptchaPopup')
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        answer, solved_by, captcha_image_blob = nil, nil
        try_solve = ->(solvers) do
          captcha_image_blob = render_element(captcha)
          solvers.each do |solver|
            answer = solver.solve(captcha)
            if answer
              solved_by = solver
              logger.debug { 'Captcha solved by [%s] solver.' % solved_by.class.name }
              stat(:captcha, :solved, solved_by.class)
              break
            end
          end
        end
        refreshes = 0
        IMAGE_CAPTCHA_REFRESHES.times do
          try_solve.call(@ocr_solvers)
          break if answer
          logger.debug { 'Provided captcha not solved by OCR engine. Refreshing.' }
          captcha = refresh_captcha(popup)
          refreshes += 1
        end
        stat(:captcha, :captcha_refreshes, refreshes)
        if answer
          logger.debug { 'Captcha solved by OCR engine after [%d] refreshes.' % refreshes }
        else
          logger.debug { 'Captcha not solved by OCR engine. Solving by external service.' }
          try_solve.call(@external_service_solvers)
        end
        unless answer
          logger.warn { 'Captcha type not recognized.' }
          stat(:captcha, :unrecognized)
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
          stat(:captcha, :accepted, answer)
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
          stat(:captcha, :rejected, answer)
          solved_by.answer_rejected
          raise Plunder::CaptchaError, 'Captcha incorrectly solved. Answer [%s] rejected.' % answer
        end
        raise Plunder::AfterClaimError, 'Unable to find captcha answer correctness element.'
      end

      def refresh_captcha(popup = nil)
        popup = browser.find(:id, 'CaptchaPopup') if popup.nil?
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        captcha.allow_reload!
        src = captcha_src(captcha)
        popup.find(:id, 'adcopy-link-refresh').click
        begin
          Timeout.timeout(dm.config.browser.fetch(:timeout, 30) / 3.0) do
            begin
              sleep(0.5)
              captcha.reload
            end while captcha_src(captcha) == src
          end
        rescue Timeout::Error
          raise Plunder::BeforeClaimError, 'Timed out waiting for captcha refresh.'
        end
        captcha
      end

      def render_element(element)
        raise Plunder::CaptchaError, 'Cannot create render of element without id.' unless element[:id] && !element[:id].to_s.empty?
        Base64.decode64(element.session.driver.render_base64(:png, selector: "\##{element[:id]}"))
      end

      private

      def has_result?(id)
        browser.find(:id, id)
        true
      rescue Capybara::ElementNotFound
        return false
      end

      def captcha_src(captcha_element)
        return captcha_element[:src] if captcha_element.tag_name == 'img'
        return captcha_element.find(:xpath, './iframe')[:src] if captcha_element.tag_name == 'div'
        nil
      rescue Capybara::ElementNotFound
        return nil
      end
    end
  end
end
