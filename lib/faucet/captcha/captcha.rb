class Faucet
  module Captcha
    class Captcha
      def self.patterns_path
        File.absolute_path(File.join(File.dirname(__FILE__), '..', '..', '..', 'var', 'captchas'))
      end
    end
  end
end
