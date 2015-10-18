require_relative '../utility/logging'
require_relative '../exceptions'

class Faucet
  module Captcha
    class Base
      include Faucet::Utility::Logging
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
    end
  end
end
