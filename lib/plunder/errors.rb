class Plunder

  # ApplicationError - application cannot continue working when raised.
  class ApplicationError < RuntimeError
  end

  class ConfigError < ApplicationError
    def initialize(msg = nil, entry_name = nil, cause = nil)
      if msg.nil? && !entry_name.nil?
        msg = 'Configuration entry [%s] invalid' % entry_name
        msg << ': ' << cause.to_s.strip unless cause.to_s.empty?
        msg << '.' unless msg.end_with?('.')
      end
      super(msg)
    end
  end

  class DependencyError < ApplicationError
  end

  # Standard Error - application may continue working when raised.
  class Error < StandardError
  end

  class BrowserError < Error
  end

  class FatalBrowserError < BrowserError
  end

  class FaucetError < Error
  end

  class AfterClaimError < FaucetError
  end

  class BeforeClaimError < FaucetError
  end

  class SigningInError < BeforeClaimError
  end

  class CaptchaError < BeforeClaimError
  end
end