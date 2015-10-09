require_relative 'captcha'
require_relative '../utility/logging'

require 'phashion'
require 'chunky_png'

class Faucet::Captcha::Sponsored < Faucet::Captcha::Captcha
  include Faucet::Utility::Logging

  def self.recognize(image)
    false
  end
end
