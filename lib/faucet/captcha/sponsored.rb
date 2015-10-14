# coding: utf-8
require 'tesseract'
require 'base64'

require_relative 'base'

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
    frame = element.find(:xpath, './iframe')
    image = browser.within_frame(frame) do
      browser.find(:id, 'playInstr')
      browser.find(:id, 'playBtn')
      browser.find(:id, 'overlay', visible: false)
      logger.debug { 'Captcha recognized as sponsored code. Starting solving.' }
      bg_image = browser.evaluate_script('window.getComputedStyle(document.querySelector(\'#overlay\')).backgroundImage').to_s
      raise Faucet::UnsolvableCaptchaError, 'sponsored captcha code element is not embedded PNG' unless bg_image.start_with?(EMBEDDED_PNG_PREFIX) && bg_image.end_with?(EMBEDDED_PNG_SUFFIX)
      Base64.decode64(bg_image.slice(EMBEDDED_PNG_PREFIX.length..(-EMBEDDED_PNG_SUFFIX.length - 1)))
    end
    text = ocr_engine.text_for(image).strip
    logger.debug { 'Sponsored captcha code text [%s] from OCR.' % text }
    PROPER_PREFIXES.each do |prefix|
      return text.slice(prefix.length..-1).strip if text.start_with?(prefix)
    end
    raise Faucet::UnsolvableCaptchaError, 'sponsored captcha code has invalid prefix'
  rescue Capybara::ElementNotFound
    return false
  end
end
