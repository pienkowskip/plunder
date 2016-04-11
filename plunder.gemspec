# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'plunder/version'

Gem::Specification.new do |spec|
  spec.name          = 'plunder'
  spec.version       = Plunder::VERSION.dup
  spec.authors       = ['Paweł Pieńkowski']
  spec.email         = ['pienkowskip@gmail.com']
  spec.summary       = 'Various online money-making bots'
  spec.description   = <<-EOF
    Various online money-making bots. Uses Capybara, PhantomJS & external captcha solving service to headlessly claim
    rewards in online money-making systems.
  EOF
  spec.homepage      = 'https://github.com/pienkowskip/plunder'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($/)
  spec.executables   = []
  spec.require_paths = ['lib', 'var']

  spec.add_runtime_dependency 'chunky_png'
  spec.add_runtime_dependency 'phashion'
  spec.add_runtime_dependency 'tesseract-ocr', '~> 0.1.9'
  spec.add_runtime_dependency 'two_captcha', '~> 1.1'
  spec.add_runtime_dependency 'poltergeist', '~> 1.9'
  spec.add_runtime_dependency 'pqueue'

  spec.add_development_dependency 'bundler', '~> 1.3'
  spec.add_development_dependency 'pry', '~> 0.10'
end
