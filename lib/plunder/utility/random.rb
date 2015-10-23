module Plunder::Utility
  class Random
    attr_reader :prng

    def initialize
      @prng = ::Random.new
      @gauss_next = nil
    end

    def rand(*args)
      @prng.rand(*args)
    end

    def sleep(*args)
      Kernel.sleep(@prng.rand(*args))
    end

    def gauss_rand(mean, stddev)
      x = @gauss_next
      @gauss_next = nil
      if x.nil?
      theta = 2 * Math::PI * @prng.rand
      rho = Math.sqrt(-2 * Math.log(1 - @prng.rand))
      x = Math.cos(theta) * rho
      @gauss_next = Math.sin(theta) * rho
      end
      mean + x * stddev
    end

    def gauss_sleep(mean, stddev)
      Kernel.sleep(gauss_rand(mean, stddev))
    end
  end
end
