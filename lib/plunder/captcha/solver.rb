require 'timeout'
require 'base64'

require_relative 'logger'
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
      include Plunder::Captcha::Logging
      extend Forwardable

      DEFAULT_MAX_CAPTCHA_REFRESHES = 3

      attr_reader :dm
      def_delegators :@dm, :browser

      def initialize(dm)
        @dm = dm
        @sub_timeout = dm.config.browser.timeout.fetch_f(30) / 3.0
        @max_captcha_refreshes = dm.config.application.captcha.ocr.max_refreshes.fetch_i(DEFAULT_MAX_CAPTCHA_REFRESHES)

        min_ocr_confidence = dm.config.application.captcha.ocr.min_confidence.fetch_f(Plunder::Captcha::ImageDecoder::OCR::DEFAULT_MIN_OCR_CONFIDENCE)
        ocr_decoder = Plunder::Captcha::ImageDecoder::OCR.new(min_ocr_confidence)
        external_service_decoder = Plunder::Captcha::ImageDecoder::ExternalService.new(dm)

        sponsored_solver = Plunder::Captcha::Sponsored.new(dm)
        @ocr_solvers = [sponsored_solver] + [Plunder::Captcha::Canvas, Plunder::Captcha::Image].map { |klass| klass.new(dm, ocr_decoder) }
        @external_service_solvers = [sponsored_solver] + [Plunder::Captcha::Canvas, Plunder::Captcha::Image].map { |klass| klass.new(dm, external_service_decoder) }
      end

      def solve_captcha
        popup = browser.find(:id, 'CaptchaPopup')
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        answer, solved_by = nil, nil
        try_solve = ->(solvers) do
          solvers.each do |solver|
            answer = solver.solve(captcha)
            if answer
              solved_by = solver
              logger.debug { 'Captcha solved by [%s] solver.' % solved_by.class.name }
              stat(:captcha, :solved, solved_by.class)
              captcha_logger[:solved_by] = solved_by.class
              break
            end
          end
        end
        refreshes = 0
        handle_new_captcha(captcha)
        try_solve.call(@ocr_solvers)
        while !answer && refreshes < @max_captcha_refreshes do
          logger.debug { 'Provided captcha not solved by OCR based solvers. Refreshing.' }
          captcha = refresh_captcha(popup)
          captcha_logger[:status] = :refreshed
          captcha_logger.log_entry
          refreshes += 1
          handle_new_captcha(captcha)
          try_solve.call(@ocr_solvers)
        end
        stat(:captcha, :captcha_refreshes, refreshes)
        if answer
          logger.debug { 'Captcha solved by OCR based solvers after [%d] refreshes.' % refreshes }
        else
          logger.debug { 'Captcha not solved by OCR based solvers. Using external service based solvers.' }
          try_solve.call(@external_service_solvers)
        end
        unless answer
          logger.warn { 'Captcha type not recognized.' }
          stat(:captcha, :unrecognized)
          captcha_logger[:status] = :unrecognized
          raise Plunder::CaptchaError, 'Captcha type not recognized.'
        end
        answer.force_encoding(Encoding::UTF_8)
        logger.debug { 'Submitting captcha answer [%s].' % answer }
        captcha_logger[:answer] = answer
        popup.find(:id, 'adcopy_response').send_keys(answer, :Enter)
        inline_rescue(Timeout::Error) do
          Timeout.timeout(@sub_timeout) do
            nil until has_result?('BodyPlaceholder_SuccessfulClaimPanel') || has_result?('BodyPlaceholder_FailedClaimPanel')
          end
        end
        if has_result?('BodyPlaceholder_SuccessfulClaimPanel')
          logger.info { 'Captcha correctly solved. Answer [%s] accepted.' % answer }
          stat(:captcha, :accepted, answer)
          dm.interval_adjuster.report(:answer_accepted)
          captcha_logger[:status] = :accepted
          solved_by.answer_accepted
          return true
        end
        if has_result?('BodyPlaceholder_FailedClaimPanel')
          logger.warn { 'Captcha incorrectly solved. Answer [%s] rejected.' % answer }
          stat(:captcha, :rejected, answer)
          dm.interval_adjuster.report(:answer_rejected)
          captcha_logger[:status] = :rejected
          solved_by.answer_rejected
          raise Plunder::CaptchaError, 'Captcha incorrectly solved. Answer [%s] rejected.' % answer
        end
        raise Plunder::AfterClaimError, 'Unable to find captcha answer correctness element.'
      ensure
        captcha_logger.log_entry if captcha_logger.has_entry?
      end

      def refresh_captcha(popup = nil)
        popup = browser.find(:id, 'CaptchaPopup') if popup.nil?
        captcha = popup.find(:id, 'adcopy-puzzle-image-image')
        captcha.allow_reload!
        src = captcha_src(captcha)
        popup.find(:id, 'adcopy-link-refresh').click
        begin
          Timeout.timeout(@sub_timeout) do
            begin
              sleep(0.3)
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

      def handle_new_captcha(captcha_element)
        if captcha_not_loaded?(captcha_element).nil?
          dm.random.sleep(0.5..1.0) # wait a little bit because loading status cannot be determined
        else
          begin
            Timeout.timeout(@sub_timeout) { sleep(0.5) while captcha_not_loaded?(captcha_element) }
          rescue Timeout::Error
            raise Plunder::BeforeClaimError, 'Timed out waiting for captcha image to load.'
          end
        end
        dm.interval_adjuster.report(:captcha_loaded)
        captcha_logger.open_entry.image = render_element(captcha_element)
      end

      def captcha_not_loaded?(captcha_element)
        return nil unless captcha_element.tag_name == 'img'
        raise Plunder::CaptchaError, 'Cannot check loading status for image without id.' unless captcha_element[:id] && !captcha_element[:id].to_s.empty?
        browser.evaluate_script(<<-JAVASCRIPT)
          (function() {
            var img = document.getElementById("#{captcha_element[:id]}");
            if (!img.complete) { return true; }
            if (img.naturalWidth === 0) { return true; }
            return false;
          })()
        JAVASCRIPT
      end
    end
  end
end
