# coding: utf-8
require 'base64'
require 'tesseract'

require_relative 'base'
require_relative '../exceptions'

class Faucet::Captcha::Sponsored < Faucet::Captcha::Base
  EMBEDDED_PNG_PREFIX = 'url(data:image/png;base64,'.freeze
  EMBEDDED_PNG_SUFFIX = ')'.freeze
  PROPER_PREFIXES = [
      'Hpisai:', # Wpisać:
      'Entrer:'
  ].freeze

  attr_reader :ocr_engine

  def initialize(dm)
    super
    @ocr_engine = Tesseract::Engine.new do |engine|
      engine.language  = :en
      engine.whitelist = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ :'
    end
  end

  def solve(element)
    frame = element.find_element(xpath: './iframe')
    dm.webdriver.switch_to.frame(frame)
    dm.webdriver.find_element(id: 'playInstr')
    dm.webdriver.find_element(id: 'playBtn')
    image = dm.webdriver.find_element(id: 'overlay').css_value('background-image')
    raise Faucet::UnsolvableCaptchaError 'sponsored captcha code element is not embedded PNG' unless image.start_with?(EMBEDDED_PNG_PREFIX) && image.end_with?(EMBEDDED_PNG_SUFFIX)
    image = Base64.decode64(image.slice(EMBEDDED_PNG_PREFIX.length..(-EMBEDDED_PNG_SUFFIX.length - 1)))
    image = ChunkyPNG::Image.from_blob(image)
    image.save('sponsored_captcha-%s.png' % Time.new.strftime('%Y%m%dT%H%M%S'))
    text = ocr_engine.text_for(image).strip #OPTIMIZE: You can pass just string from decoded background-image.
    logger.debug { 'Sponsored captcha code solved via OCR: "%s".' % text }
    PROPER_PREFIXES.each do |prefix|
      return text.slice(prefix.length..-1).strip if text.start_with?(prefix)
    end
    raise Faucet::UnsolvableCaptchaError 'sponsored captcha code has invalid prefix'
  rescue Selenium::WebDriver::Error::NoSuchElementError
    return false
  ensure
    dm.webdriver.switch_to.default_content
  end
end
