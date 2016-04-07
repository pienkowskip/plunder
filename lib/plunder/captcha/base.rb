require 'chunky_png'

require_relative '../utility/logging'
require_relative '../errors'

class Plunder
  module Captcha
    class Base
      include Plunder::Utility::Logging
      extend Forwardable

      attr_reader :dm
      def_delegators :@dm, :browser

      def initialize(dm)
        @dm = dm
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
