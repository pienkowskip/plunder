require 'tesseract'

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
          charset = 'abcdefghijklmnopqrstuvwxyz .,-\'!?'
          @ocr_engines = [charset, charset.upcase].map do |whitelist|
            Tesseract::Engine.new do |engine|
              engine.language = :en
              engine.whitelist = whitelist
            end
          end.zip([0, -15])
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
          best_result = nil
          @ocr_engines.each do |engine, confidence_factor|
            result = ocr(image, engine)
            next if result.nil?
            result.push(result[1] + confidence_factor)
            best_result = result if best_result.nil? || result[2] > best_result[2]
          end
          if best_result.nil?
            logger.warn { 'OCR engine failed to solve captcha. Internal error.' }
            stat(:captcha, :ocr, :failure)
            save_suspected_captcha(image)
            return false
          end
          text, confidence, _ = best_result
          stat(:captcha, :ocr, '%.1f' % confidence)
          if confidence >= @min_ocr_confidence
            logger.debug { 'Captcha text [%s] received from OCR engine with confidence [%.1f%%].' %  [text, confidence] }
            text
          else
            logger.debug { 'Confidence [%.1f%%] of captcha-solving OCR engine results is too low.' % confidence }
            false
          end
        end

        private

        def ocr(image, engine)
          block = engine.blocks_for(image)
          return nil unless block.size == 1
          block = block[0]
          return nil if block.text.nil?
          return block.text.strip.gsub(/\s+/, ' '), block.confidence
        end

        def save_suspected_captcha(image)
          image.save(File.join(@dm.config.application[:error_log], 'captcha-ocr_engine_failure-%s.png' % Time.now.strftime('%FT%H%M%S'))) if @dm.config.application[:error_log]
        rescue => exc
          raise Plunder::ApplicationError, 'Cannot save image of captcha bypassed to OCR solving. Error: %s (%s).' % [exc.message, exc.class]
        end
      end
    end
  end
end