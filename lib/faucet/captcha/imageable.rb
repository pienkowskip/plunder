require 'chunky_png'
require 'base64'
require 'cgi'

require_relative '../utility/logging'
require_relative '../exceptions'

class Faucet
  module Captcha
    module Imageable
      include Faucet::Utility::Logging

      BIG_CAPTCHA_SIZE = 400

      protected

      def imageable_initialize(dm)
        @imageable_dm = dm
      end

      def element_render(element)
        raise Faucet::UnsolvableCaptchaError, 'cannot create render of element without id' unless element[:id] && !element[:id].to_s.empty?
        base64 = element.session.driver.render_base64(:png, selector: "\##{element[:id]}")
        ChunkyPNG::Image.from_blob(Base64.decode64(base64))
      end

      def solve_image(image)
        if image.width + image.height >= BIG_CAPTCHA_SIZE
          size = 0.98 * BIG_CAPTCHA_SIZE.to_f
          new_width = size / (1.0 + image.height.to_f / image.width.to_f)
          image = image.resample_bilinear(new_width.round, (size - new_width).round)
        end
        logger.debug { 'Bypassing captcha image to external service [2captcha.com].' }
        text = @imageable_dm.two_captcha_client.decode(raw: image.to_blob).text
        if text.nil?
          logger.warn { 'Captcha solving external service [2captcha.com] returned error.' }
          raise Faucet::UnsolvableCaptchaError, 'captcha solving external service error'
        end
        text = CGI.unescapeHTML(text)
        logger.debug { 'Captcha text [%s] received from external service [2captcha.com].' %  text }
        text
      end
    end
  end
end
