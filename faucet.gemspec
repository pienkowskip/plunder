# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'faucet/version'

Gem::Specification.new do |spec|
  spec.name          = 'faucet'
  spec.version       = Faucet::VERSION.dup
  spec.authors       = ['Paweł Pieńkowski']
  spec.email         = ['pienkowskip@gmail.com']
  spec.summary       = 'Crypto-currency faucets bot'
  spec.description   = <<-EOF
    Crypto-currency faucets bot. Uses selenium, Xvfb & external captcha solving service to headlessly claim
    crypto-currency from web faucet.
  EOF
  spec.homepage      = 'https://github.com/pienkowskip/faucet'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = ['faucet']
  spec.require_paths = ['lib', 'var']

  spec.add_runtime_dependency 'selenium-webdriver', '~> 2.48'
  spec.add_runtime_dependency 'chunky_png'
  spec.add_runtime_dependency 'phashion'
  spec.add_runtime_dependency 'tesseract-ocr'
  spec.add_runtime_dependency 'two_captcha'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'pry', '~> 0.10'
end
