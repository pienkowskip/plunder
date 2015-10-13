require_relative 'base'

class Faucet::Captcha::Canvas < Faucet::Captcha::Base
  BIG_CAPTCHA_SIZE = 400

  def solve(element)
    frame = element.find_element(xpath: './iframe')
    dm.webdriver.switch_to.frame(frame)
    instruction_span = dm.webdriver.find_element(id: 'instr')
    return false unless instruction_span.text == 'Enter the following:'
    image = element_screenshot(dm.webdriver.find_element(tag_name: 'canvas', id: 'slog'))
    top = instruction_span.size.height + 3
    image.crop!(3, top, image.width - 2 * 3, image.height - top - 3)
    solve_image(image)
  rescue Selenium::WebDriver::Error::NoSuchElementError
    return false
  ensure
    dm.webdriver.switch_to.default_content
  end

  protected

  def solve_image(image)
    if image.width + image.height >= BIG_CAPTCHA_SIZE
      size = 0.98 * BIG_CAPTCHA_SIZE.to_f
      new_width = size / (1.0 + image.height.to_f / image.width.to_f)
      image = image.resample_bilinear(new_width.round, (size - new_width).round)
    end
    result = dm.two_captcha_client.decode(raw: image.to_blob)
    result.text
  end

  # 400 = nw + nh
  # nw/w = nh/h => nh = nw*h / w
  # 400 = nw + nw * h / w = nw (1 + h/w)
  # nw = 400 / (1 + h/w)
  # nh = 400 - nw
end
