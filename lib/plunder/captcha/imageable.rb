require 'chunky_png'
require 'base64'
require 'cgi'

require_relative '../utility/logging'
require_relative '../utility/stats'
require_relative '../errors'

class Plunder
  module Captcha
    module Imageable
      include Plunder::Utility::Logging
      include Plunder::Utility::Stats

      BIG_CAPTCHA_SIZE = 400
      DEFAULT_MIN_OCR_CONFIDENCE = 70

      def answer_rejected
        if @last_captcha_id
          logger.info { 'Reporting incorrect answer of captcha [%s] to external service [2captcha.com].' % @last_captcha_id }
          stat(:captcha, :external, :report, @last_captcha_id)
          @imageable_dm.two_captcha_client.report!(@last_captcha_id)
        end
      end

      protected

      def imageable_initialize(dm)
        @imageable_dm = dm
        @last_captcha_id = nil
        @min_ocr_confidence = dm.config.application.fetch(:min_ocr_confidence, DEFAULT_MIN_OCR_CONFIDENCE)
        begin
          @min_ocr_confidence = Float(@min_ocr_confidence)
          raise ArgumentError, 'not finite number' unless @min_ocr_confidence.finite?
        rescue
          raise Plunder::ConfigEntryError.new('application.min_ocr_confidence', 'not a valid number')
        end
      end

      def element_render(element)
        raise Plunder::CaptchaError, 'Cannot create render of element without id.' unless element[:id] && !element[:id].to_s.empty?
        base64 = element.session.driver.render_base64(:png, selector: "\##{element[:id]}")
        ChunkyPNG::Image.from_blob(Base64.decode64(base64))
      end

      def solve_captcha_image(image)
        @last_captcha_id = nil
        answer = solve_with_ocr(image)
        return answer if answer
        solve_with_external_service(image)
      end

      private

      def save_suspected_captcha(image)
        image.save(File.join(dm.config.application[:error_log], 'captcha-ocr_engine_failure-%s.png' % Time.now.strftime('%FT%H%M%S'))) if dm.config.application[:error_log]
      rescue => exc
        raise Plunder::ApplicationError, 'Cannot save image of captcha bypassed to OCR solving. Error: %s (%s).' % [exc.message, exc.class]
      end

      def solve_with_ocr(image)
        logger.debug { 'Solving captcha image via OCR engine.' }
        block = dm.ocr_engine.blocks_for(image)
        unless block.size == 1
          logger.warn { 'OCR engine returned invalid number of blocks. Should be one.' }
          stat(:captcha, :ocr, :failure)
          save_suspected_captcha(image)
          return false
        end
        block = block[0]
        if block.text.nil?
          logger.warn { 'OCR engine failed to solve captcha. Internal error.' }
          stat(:captcha, :ocr, :failure)
          save_suspected_captcha(image)
          return false
        end
        stat(:captcha, :ocr, '%.1f' % block.confidence)
        if block.confidence >= @min_ocr_confidence
          text = block.text.strip.gsub(/\s+/, ' ')
          logger.debug { 'Captcha text [%s] received from OCR engine with confidence [%.1f%%].' %  [text, block.confidence] }
          text
        else
          logger.debug { 'Confidence [%.1f%%] of captcha-solving OCR engine results is too low.' % block.confidence }
          false
        end
      end

      def solve_with_external_service(image)
        if image.width + image.height >= BIG_CAPTCHA_SIZE
          size = 0.98 * BIG_CAPTCHA_SIZE.to_f
          new_width = size / (1.0 + image.height.to_f / image.width.to_f)
          image = image.resample_bilinear(new_width.round, (size - new_width).round)
        end
        logger.debug { 'Bypassing captcha image to external service [2captcha.com].' }
        captcha = @imageable_dm.two_captcha_client.decode(raw: image.to_blob) #TODO: Handle TwoCaptcha exceptions like timeout.
        text = captcha.text
        text = CGI.unescapeHTML(text).strip unless text.nil?
        if text.nil? || text.empty? || !captcha.id
          logger.warn { 'Captcha solving external service [2captcha.com] returned error.' }
          stat(:captcha, :external, :failure)
          raise Plunder::CaptchaError, 'Captcha solving external service [2captcha.com] error.'
        end
        @last_captcha_id = captcha.id
        logger.debug { 'Captcha text [%s] received from external service [2captcha.com].' %  text }
        stat(:captcha, :external, :answer, text)
        text
      end
    end
  end
end
