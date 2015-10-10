require 'base64'

require_relative 'captcha'
require_relative '../exceptions'

class Faucet::Captcha::Sponsored < Faucet::Captcha::Captcha
  EMBEDDED_PNG_PREFIX = 'url(data:image/png;base64,'.freeze
  EMBEDDED_PNG_SUFFIX = ')'.freeze

  def solve(element)
    frame = element.find_element(xpath: './iframe')
    webdriver.switch_to.frame(frame)
    webdriver.find_element(id: 'playInstr')
    webdriver.find_element(id: 'playBtn')
    image = webdriver.find_element(id: 'overlay').css_value('background-image')
    raise Faucet::UnsolvableCaptchaError 'sponsored captcha code element is not embedded PNG' unless image.start_with?(EMBEDDED_PNG_PREFIX) && image.end_with?(EMBEDDED_PNG_SUFFIX)
    image = Base64.decode64(image.slice(EMBEDDED_PNG_PREFIX.length..(-EMBEDDED_PNG_SUFFIX.length - 1)))
    ChunkyPNG::Image.from_blob(image).save('sponsored_captcha-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S'))
    true
  rescue Selenium::WebDriver::Error::NoSuchElementError
    return false
  ensure
    webdriver.switch_to.default_content
  end
end
