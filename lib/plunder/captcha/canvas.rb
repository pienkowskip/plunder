require_relative 'base'

class Plunder::Captcha::Canvas < Plunder::Captcha::Base

  def initialize(dm, image_decoder)
    super(dm)
    @image_decoder = image_decoder
  end

  def solve(element)
    frame = element.find(:xpath, './iframe')
    top = 0
    browser.within_frame(frame) do
      slog = browser.find(:id, 'slog')
      return false unless browser.find('#top > #instr').text == 'Enter the following:'
      if slog.tag_name == 'span'
        text = slog.text.strip
        logger.debug { 'Captcha recognized as span with text [%s].' % text }
        captcha_logger[:canvas_with_span] = true
        return text
      end
      logger.debug { 'Captcha recognized as canvas. Starting solving.' }
      top = browser.evaluate_script('document.querySelector(\'#top\').clientHeight').to_i
    end
    image = element_image(element)
    image.crop!(5, top + 2, image.width - 2 * 5, image.height - top - 2)
    simplify_image!(image)
    captcha_logger.cropped_image = image
    @image_decoder.decode(image)
  rescue Capybara::ElementNotFound
    return false
  end

  def answer_rejected
    @image_decoder.answer_rejected if @image_decoder.respond_to?(:answer_rejected)
  end
end
