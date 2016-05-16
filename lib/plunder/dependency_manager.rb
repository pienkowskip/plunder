require 'two_captcha'

require_relative 'errors'
require_relative 'captcha/solver'
require_relative 'utility/scheduler'
require_relative 'utility/random'
require_relative 'utility/interval_adjuster'

class Plunder::DependencyManager
  DEPENDENCIES = {
      plunder: nil,
      config: nil,
      browser: nil,
      captcha_solver: ->(dm) { Plunder::Captcha::Solver.new(dm) },
      two_captcha_client: ->(dm) do
        TwoCaptcha.new(dm.config.auth.nested('2captcha.com').api_key.fetch, timeout: 120)
      end,
      random: ->(_) do
        Plunder::Utility::Random.new
      end,
      scheduler: ->(_) do
        Plunder::Utility::Scheduler.new
      end,
      interval_adjuster: ->(_) do
        Plunder::Utility::IntervalAdjuster.new(8, 1)
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
end