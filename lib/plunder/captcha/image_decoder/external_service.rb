require 'cgi'

require_relative '../../utility/logging'
require_relative '../../utility/stats'
require_relative '../../errors'

class Plunder
  module Captcha
    module ImageDecoder
      class ExternalService
        include Plunder::Utility::Logging
        include Plunder::Utility::Stats

        BIG_CAPTCHA_SIZE = 400

        def initialize(two_captcha_client)
          @last_captcha_id = nil
          @two_captcha_client = two_captcha_client
        end

        def decode(image)
          if image.width + image.height >= BIG_CAPTCHA_SIZE
            size = 0.98 * BIG_CAPTCHA_SIZE.to_f
            new_width = size / (1.0 + image.height.to_f / image.width.to_f)
            image = image.resample_bilinear(new_width.round, (size - new_width).round)
          end
          logger.debug { 'Bypassing captcha image to external service [2captcha.com].' }
          captcha = @two_captcha_client.decode(raw: image.to_blob) #TODO: Handle TwoCaptcha exceptions like timeout.
          text = captcha.text
          text = CGI.unescapeHTML(text).strip unless text.nil?
          if text.nil? || text.empty? || !captcha.id
            logger.warn { 'Captcha solving external service [2captcha.com] returned error.' }
            stat(:captcha, :external, :failure)
            raise Plunder::CaptchaError, 'Captcha solving external service [2captcha.com] error.'
          end
          @last_captcha_id = captcha.id
          logger.debug { 'Captcha text [%s] received from external service [2captcha.com]. Solving cost: [%s].' %  [text, ('%.5f' % captcha.cost rescue 'n/a')] }
          stat(:captcha, :external, :response, captcha.id, text, captcha.cost)
          text
        end

        def answer_rejected
          if @last_captcha_id
            logger.info { 'Reporting incorrect answer of captcha [%s] to external service [2captcha.com].' % @last_captcha_id }
            stat(:captcha, :external, :report, @last_captcha_id)
            @two_captcha_client.report!(@last_captcha_id)
          end
        end
      end
    end
  end
end