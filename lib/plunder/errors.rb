class Plunder

  # ApplicationError - application cannot continue working when raised.
  class ApplicationError < RuntimeError
  end

  class ConfigError < ApplicationError
  end

  class ConfigEntryError < ConfigError
    def initialize(entry_name, cause)
      msg = "#{entry_name} configuration entry invalid"
      msg << ' - ' << cause.to_s unless cause.to_s.empty?
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