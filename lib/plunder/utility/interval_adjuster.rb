module Plunder::Utility
  class IntervalAdjuster
    EVENT_ADJUST_MAP = {
        answer_accepted: Rational(-6, 100),
        answer_rejected: Rational(3, 100),
        captcha_loaded: Rational(1, 100),
        external_service: Rational(18, 100)
    }.freeze

    attr_reader :max_factor, :min_factor

    def initialize(max_factor = nil, min_factor = 1)
      @max_factor = max_factor.is_a?(Numeric) ? max_factor.to_r : max_factor
      @min_factor = min_factor.is_a?(Numeric) ? min_factor.to_r : min_factor
      @factor = 1.to_r
    end

    def factor
      @factor.to_f
    end

    def report(event)
      raise ArgumentError, 'Unknown [%s] event reported.' % event.inspect unless EVENT_ADJUST_MAP.include?(event)
      @factor += EVENT_ADJUST_MAP[event]
      @factor = max_factor if max_factor && @factor > max_factor
      @factor = min_factor if min_factor && @factor < min_factor
      factor
    end
  end
end