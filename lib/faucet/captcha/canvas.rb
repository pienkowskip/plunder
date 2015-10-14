require 'chunky_png'
require 'base64'

require_relative 'base'

class Faucet::Captcha::Canvas < Faucet::Captcha::Base
  BIG_CAPTCHA_SIZE = 400

  def solve(element)
    frame = element.find(:xpath, './iframe')
    top = 0
    browser.within_frame(frame) do
      browser.find(:id, 'slog')
      return false unless browser.find('#top > #instr').text == 'Enter the following:'
      logger.debug { 'Captcha recognized as canvas. Starting solving.' }
      top = browser.evaluate_script('document.querySelector(\'#top\').clientHeight').to_i
    end
    image = element_render(element)
    image.crop!(3, top + 3, image.width - 2 * 3, image.height - top - 2 * 3)
    solve_image(image)
  rescue Capybara::ElementNotFound
    return false
  end

  protected

  def element_render(element)
    raise Faucet::UnsolvableCaptchaError, 'cannot create render of element without id' unless element[:id] && !element[:id].to_s.empty?
    base64 = browser.driver.render_base64(:png, selector: "\##{element[:id]}")
    ChunkyPNG::Image.from_blob(Base64.decode64(base64))
  end

  def solve_image(image)
    if image.width + image.height >= BIG_CAPTCHA_SIZE
      size = 0.98 * BIG_CAPTCHA_SIZE.to_f
      new_width = size / (1.0 + image.height.to_f / image.width.to_f)
      image = image.resample_bilinear(new_width.round, (size - new_width).round)
    end
    image.save('to_service-' + Time.new.strftime('%Y%m%dT%H%M%S') + '.png')
    logger.debug { 'Captcha image bypassed to external service [2captcha.com].' }
    result = dm.two_captcha_client.decode(raw: image.to_blob)
    logger.debug { 'Captcha text [%s] received from external service [2captcha.com].' %  result.text }
    result.text #TODO: Handle null response.
  end
end
