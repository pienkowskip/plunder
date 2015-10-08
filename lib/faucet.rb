require_relative 'faucet/version'
require_relative 'faucet/config'
require_relative 'faucet/utility/logging'

class Faucet
  include Utility::Logging

  attr_reader :config

  def initialize(config_filename)
    @config = Config.new(config_filename).freeze
  end
end
