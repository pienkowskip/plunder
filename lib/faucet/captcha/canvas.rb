require_relative 'captcha'

class Faucet::Captcha::Canvas < Faucet::Captcha::Captcha
  def solve(element)
    frame = element.find_element(xpath: './iframe')
    webdriver.switch_to.frame(frame)
    instruction_span = webdriver.find_element(id: 'instr')
    return false unless instruction_span.text == 'Enter the following:'
    image = element_screenshot(webdriver.find_element(tag_name: 'canvas', id: 'slog'))
    top = instruction_span.size.height + 3
    image.crop!(3, top, image.width - 2 * 3, image.height - top - 3)
    image.save('canvas_captcha-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S')) #TODO: Solve instead save.
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    return false
  ensure
    webdriver.switch_to.default_content
  end
end
