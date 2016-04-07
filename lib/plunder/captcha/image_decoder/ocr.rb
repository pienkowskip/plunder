require_relative '../../utility/logging'
require_relative '../../utility/stats'
require_relative '../../errors'

class Plunder
  module Captcha
    module ImageDecoder
      class OCR
        include Plunder::Utility::Logging
        include Plunder::Utility::Stats

        DEFAULT_MIN_OCR_CONFIDENCE = 70

        def initialize(dm)
          @dm = dm
          @min_ocr_confidence = @dm.config.application.fetch(:min_ocr_confidence, DEFAULT_MIN_OCR_CONFIDENCE)
          begin
            @min_ocr_confidence = Float(@min_ocr_confidence)
            raise ArgumentError, 'not finite number' unless @min_ocr_confidence.finite?
          rescue
            raise Plunder::ConfigEntryError.new('application.min_ocr_confidence', 'not a valid number')
          end
        end

        def decode(image)
          logger.debug { 'Solving captcha image via OCR engine.' }
          block = @dm.ocr_engine.blocks_for(image)
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

        private

        def save_suspected_captcha(image)
          image.save(File.join(@dm.config.application[:error_log], 'captcha-ocr_engine_failure-%s.png' % Time.now.strftime('%FT%H%M%S'))) if @dm.config.application[:error_log]
        rescue => exc
          raise Plunder::ApplicationError, 'Cannot save image of captcha bypassed to OCR solving. Error: %s (%s).' % [exc.message, exc.class]
        end
      end
    end
  end
end