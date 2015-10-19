require 'chunky_png'
require 'base64'
require 'cgi'

require_relative '../utility/logging'
require_relative '../errors'

class Plunder
  module Captcha
    module Imageable
      include Plunder::Utility::Logging

      BIG_CAPTCHA_SIZE = 400

      def answer_rejected
        if @last_captcha_id
          logger.info { 'Reporting incorrect answer of captcha [%s] to external service [2captcha.com].' % @last_captcha_id }
          @imageable_dm.two_captcha_client.report!(@last_captcha_id)
        end
      end

      protected

      def imageable_initialize(dm)
        @imageable_dm = dm
        @last_captcha_id = nil
      end

      def element_render(element)
        raise Plunder::CaptchaError, 'Cannot create render of element without id.' unless element[:id] && !element[:id].to_s.empty?
        base64 = element.session.driver.render_base64(:png, selector: "\##{element[:id]}")
        ChunkyPNG::Image.from_blob(Base64.decode64(base64))
      end

      def solve_image(image)
        @last_captcha_id = nil
        if image.width + image.height >= BIG_CAPTCHA_SIZE
          size = 0.98 * BIG_CAPTCHA_SIZE.to_f
          new_width = size / (1.0 + image.height.to_f / image.width.to_f)
          image = image.resample_bilinear(new_width.round, (size - new_width).round)
        end
        logger.debug { 'Bypassing captcha image to external service [2captcha.com].' }
        captcha = @imageable_dm.two_captcha_client.decode(raw: image.to_blob)
        text = captcha.text
        text = CGI.unescapeHTML(text).strip unless text.nil?
        if text.nil? || text.empty? || !captcha.id
          logger.warn { 'Captcha solving external service [2captcha.com] returned error.' }
          raise Plunder::CaptchaError, 'Captcha solving external service [2captcha.com] error.'
        end
        @last_captcha_id = captcha.id
        logger.debug { 'Captcha text [%s] received from external service [2captcha.com].' %  text }
        text
      end
    end
  end
end
