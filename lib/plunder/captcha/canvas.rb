require_relative 'base'
require_relative 'imageable'

class Plunder::Captcha::Canvas < Plunder::Captcha::Base
  include Plunder::Captcha::Imageable

  def initialize(dm)
    super
    imageable_initialize(dm)
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
        return text
      end
      logger.debug { 'Captcha recognized as canvas. Starting solving.' }
      top = browser.evaluate_script('document.querySelector(\'#top\').clientHeight').to_i
    end
    image = element_render(element)
    image.crop!(3, top + 3, image.width - 2 * 3, image.height - top - 2 * 3)
    solve_image(image)
  rescue Capybara::ElementNotFound
    return false
  end
end
