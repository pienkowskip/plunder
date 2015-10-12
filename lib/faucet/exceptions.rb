class Faucet
  class ConfigError < RuntimeError
  end

  class ConfigEntryError < ConfigError
    def initialize(entry_name, cause)
      msg = "#{entry_name} configuration entry invalid"
      msg << ' - ' << cause.to_s unless cause.to_s.empty?
      super(msg)
    end
  end

  class DependencyError < RuntimeError
  end

  class UnsolvableCaptchaError < StandardError
  end

  class SigningInError < StandardError
  end

  class ClaimingError < StandardError
  end
end