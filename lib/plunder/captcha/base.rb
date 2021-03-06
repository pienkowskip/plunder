require 'chunky_png'

require_relative '../utility/logging'
require_relative '../errors'
require_relative 'logger'
require_relative 'simplifier'

class Plunder
  module Captcha
    class Base
      include Plunder::Utility::Logging
      include Plunder::Captcha::Logging
      extend Forwardable

      attr_reader :dm
      def_delegators :@dm, :browser
      def_delegators :@simplifier, :simplify_image!
      protected :simplify_image!

      def initialize(dm)
        @dm = dm
        @simplifier = Plunder::Captcha::Simplifier.new
      end

      def answer_accepted
      end

      def answer_rejected
      end

      protected

      def element_image(element)
        ChunkyPNG::Image.from_blob(dm.captcha_solver.render_element(element))
      end
    end
  end
end
