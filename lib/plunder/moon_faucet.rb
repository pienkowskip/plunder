require 'forwardable'

require_relative 'utility/logging'
require_relative 'utility/stats'
require_relative 'errors'
require_relative '../bigdecimal_ext'

class Plunder::MoonFaucet
  include Plunder::Utility::Logging
  include Plunder::Utility::Stats
  extend Forwardable

  ClaimResult = Struct.new(:amount, :unit, :frac_len, :what) do
    PATTERN = /\A([0-9]+(\.[0-9]+)?)\ (?:(%)\ )?(.+)\ more\ info\z/.freeze

    def initialize(string, default_unit)
      md = PATTERN.match(string)
      raise Plunder::AfterClaimError, 'Claim result text [%s] do not match extracting regexp.' % string unless md
      self.frac_len = md[2].nil? ? 0 : md[2].length - 1
      self.amount = md[1].to_d
      self.unit = md[3].nil? ? default_unit : md[3]
      self.what = md[4]
    end
  end

  GaussianClaimInterval = Struct.new(:mean, :std_dev, :min) do
    def interval(dm)
      apply_min(dm.random.gauss_rand(mean, std_dev))
    end

    protected

    def apply_min(interval)
      return min if !min.nil? && interval < min
      return 0 if interval < 0
      interval
    end
  end

  class AdjustedGaussianClaimInterval < GaussianClaimInterval
    def interval(dm)
      apply_min(dm.random.gauss_rand(mean, std_dev) * dm.interval_adjuster.factor)
    end
  end

  DEFAULT_CAPTCHA_SOLVING_TRIES = 3

  attr_reader :dm, :url, :address
  def_delegators :@dm, :browser

  def initialize(dm, url, address, claim_interval = AdjustedGaussianClaimInterval.new(7 * 60, 45, 5 * 60))
    @dm, @url, @address = dm, url, address
    @claim_interval = claim_interval.dup.freeze
    @claim_retry_delays = [
        [Plunder::FatalBrowserError, GaussianClaimInterval.new(15, 3)],
        [Plunder::BrowserError, GaussianClaimInterval.new(60, 8)],
        [Plunder::AfterClaimError, @claim_interval],
        [Plunder::BeforeClaimError, GaussianClaimInterval.new(30, 4)],
        [Plunder::Error, GaussianClaimInterval.new(40, 6)]
    ].freeze
    stat(:application, :init, :faucet, url, address)
  end

  def claim
    begin
      browser.visit(url)
      logger.debug { 'Claiming URL [%s] loaded.' % url }
      accept_cookies
      sign_in
      dm.random.sleep(1.0..2.0)
      logger.debug { 'Beginning to perform claim for [%s].' % address }
      stat(:claim, :begin, url, address)
      browser.find(:id, 'SubmitButton').click
      solve_captcha(dm.config.application.captcha.solving_tries.fetch_i(DEFAULT_CAPTCHA_SOLVING_TRIES))
    rescue Capybara::ElementNotFound => exc
      raise Plunder::BeforeClaimError, 'Element required in claiming flow not found (%s).' % exc.message
    end
    dm.random.sleep(1.0..2.0)
    grab_results
  rescue Capybara::Poltergeist::TimeoutError => exc
    raise Plunder::BrowserError, 'Timed out waiting for response to [%s].' % exc.instance_variable_get(:@message)
  rescue Capybara::Poltergeist::StatusFailError
    raise Plunder::BrowserError, 'Request failed to reach the server. Check networking and/or server status.'
  rescue Plunder::Error, Plunder::ApplicationError => exc
    raise exc
  rescue Errno::ECONNRESET, Errno::EPIPE, Capybara::Poltergeist::DeadClient => exc
    raise Plunder::FatalBrowserError, 'Browser error occurred: %s (%s). Restart is required.' % [exc.message, exc.class]
  rescue => exc
    raise Plunder::ApplicationError, 'Unknown error occurred during claiming: %s (%s).' % [exc.message, exc.class]
  end

  def next_claim_delay(exc = nil)
    return @claim_interval.interval(dm) unless exc
    delay = @claim_retry_delays.find(nil) { |klass,_| exc.is_a?(klass) }
    raise Plunder::ApplicationError, 'Claim retry delay not defined for [%s] exception.' % exc.class if delay.nil?
    delay[1].interval(dm)
  end

  private

  def accept_cookies
    browser.find(:css, 'a.cc_btn_accept_all').click
    logger.debug { 'Cookies consent banner dismissed.' }
    true
  rescue Capybara::ElementNotFound
    false
  end

  def signed_in?
    browser.find(:id, 'BodyPlaceholder_ClaimPanel').find(:id, 'SignedInPaymentAddress').value == address
  rescue Capybara::ElementNotFound
    false
  end

  def sign_in
    return true if signed_in?
    logger.debug { 'Not signed in as address [%s].' % address }
    browser.driver.set_cookie('user', "PaymentAddress=#{address}")
    browser.visit(url)
    unless signed_in?
      logger.warn { 'Signing in as address [%s] failure. Unknown reason.' % address }
      raise Plunder::SigningInError, 'Signing in as address [%s] failure. Unknown reason.' % address
    end
    logger.info { 'Signing in as address [%s] success.' % address }
    true
  end

  def solve_captcha(solving_tries)
    dm.random.sleep(4.0..6.0)
    dm.captcha_solver.solve_captcha
  rescue Plunder::CaptchaError => exc
    solving_tries -= 1
    raise exc unless solving_tries > 0
    logger.debug { 'Captcha solving error. Retrying.' }
    popup = inline_rescue(Capybara::ElementNotFound, false) { browser.find(:id, 'CaptchaPopup') }
    if popup
      dm.captcha_solver.refresh_captcha(popup)
    else
      browser.find(:id, 'SubmitButton').click
    end
    retry
  end

  def grab_results
    balance = browser.find(:id, 'AccountBalanceLabel')[:title]
    md = /\Abalance:\ ([0-9]+(?:\.[0-9]+)?)\ (.+)\z/.match(balance)
    raise Plunder::AfterClaimError, 'Account balance text [%s] do not match extracting regexp.' % balance unless md
    balance, unit = md[1].to_d, md[2]
    claim_results = browser.find_all(:css, '#BodyPlaceholder_SuccessfulClaimPanel .success-message-panel').map(&:text)
    raise Plunder::AfterClaimError, 'Invalid claim results quantity.' unless claim_results.size == 4
    claim_results.map! { |cr| ClaimResult.new(cr, unit) }
    raise Plunder::AfterClaimError, 'Invalid claim result unit.' unless claim_results[0].unit == unit && claim_results.last(3).all? { |cr| cr.unit == '%' }
    claimed = claim_results[0].amount
    bonus = claim_results.last(3).map(&:amount).reduce(:+)
    granted = (claimed * (100.to_d + bonus.to_d) / 100.to_d)
    frac_len_fmt = "%.#{claim_results[0].frac_len}f"
    logger.info { "Successful claim. [#{frac_len_fmt} %s] claimed + [%d %%] bonuses = [#{frac_len_fmt} %s] granted to address [%s]." %
        [claimed, unit, bonus.round, granted, unit, address] }
    stat(:claim, :success, url, address, unit, frac_len_fmt % balance, frac_len_fmt % granted, bonus.to_i, *claim_results.map {|cr| "%s: %.#{cr.frac_len}f" % [cr.what, cr.amount] })
    return granted
  rescue Capybara::ElementNotFound => exc
    raise Plunder::AfterClaimError, 'Element required for grabbing claim results not found (%s).' % exc.message
  end
end