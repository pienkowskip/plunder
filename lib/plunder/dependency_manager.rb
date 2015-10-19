require 'two_captcha'

require_relative 'errors'
require_relative 'captcha/solver'

class Plunder::DependencyManager
  DEPENDENCIES = {
      plunder: nil,
      config: nil,
      browser: nil,
      captcha_solver: ->(dm) { Plunder::Captcha::Solver.new(dm) },
      two_captcha_client: ->(dm) do
        api_key = begin
          dm.config.auth.fetch(:'2captcha.com').fetch(:api_key)
        rescue KeyError
          raise Plunder::ConfigEntryError, 'Configuration of 2captcha.com API invalid. Lack of authentication key.'
        end
        TwoCaptcha.new(api_key, timeout: 120)
      end,
      prng: ->(_) do
        Random.new
      end
  }.freeze

  DEPENDENCIES.each do |dependency, constructor|
    dependency_var = :"@#{dependency}"
    if constructor.nil?
      define_method(dependency) do
        var = instance_variable_get(dependency_var)
        raise Plunder::DependencyError, "Dependency [#{dependency}] variable is not set." if var.nil?
        var
      end
      define_method(:"#{dependency}=") { |value| instance_variable_set(dependency_var, value) }
    else
      define_method(dependency) do
        var = instance_variable_get(dependency_var)
        return var unless var.nil?
        instance_variable_set(dependency_var, constructor.call(self))
      end
    end
    define_method(:"#{dependency}?") { !instance_variable_get(dependency_var).nil? }
  end

  def sleep_rand(*args)
    sleep prng.rand(*args)
  end
end