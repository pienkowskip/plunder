class Plunder

  #ApplicationError - application cannot continue working when raised.
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

  #Standard Error - application may continue working when raised.
  class Error < StandardError
  end

  class UnknownError < Error
  end

  class BrowserError < Error
  end

  class ClaimingError < Error
  end

  class AfterClaimError < ClaimingError
  end

  class BeforeClaimError < ClaimingError
  end

  # Let's try without this one:
  # class TimeoutError < BeforeClaimError
  # end

  class SigningInError < BeforeClaimError
  end

  class CaptchaError < BeforeClaimError
  end

  #Old errors:

  # class CaptchaError < StandardError
  # end

  # class SigningInError < StandardError
  # end
  #
  # class ClaimingError < StandardError
  # end
  #
  # class AfterClaimingError < ClaimingError
  # end
end