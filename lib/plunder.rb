require 'capybara/poltergeist'
require 'chunky_png'

require_relative 'plunder/version'
require_relative 'plunder/dependency_manager'
require_relative 'plunder/config'
require_relative 'plunder/utility/logging'
require_relative 'bigdecimal_ext'

class Plunder
  include Utility::Logging
  extend Forwardable

  ClaimResult = Struct.new(:amount, :unit, :what) do
    PATTERN = /\A([0-9]+(?:\.[0-9]+)?)\ (?:(%)\ )?(.+)\ more\ info\z/.freeze #TODO: Get fractional part length from regex.

    def initialize(string, default_unit)
      md = PATTERN.match(string)
      raise ArgumentError unless md
      self.amount = md[1].to_d
      self.unit = md[2].nil? ? default_unit : md[2]
      self.what = md[3]
      self.amount = self.amount.no_frac_to_i
    end
  end

  CAPTCHA_SOLVER_RETRIES = 3

  attr_reader :dm
  def_delegators :@dm, :browser, :browser?

  def initialize(config_filename)
    @dm = DependencyManager.new
    @dm.plunder = self
    @dm.config = Config.new(config_filename).freeze
  end

  def setup_browser
    browser_cfg = dm.config.browser
    Capybara.ignore_hidden_elements = true
    # Capybara.default_max_wait_time = 3
    case browser_cfg.fetch(:webdriver).to_sym
      when :poltergeist
        options = {
            window_size: [1280, 1024], #SXGA
            js_errors: false,
            phantomjs_logger: File.open('/dev/null', 'a'),
            phantomjs_options: [],
            # logger: STDOUT,
            # phantomjs_logger: STDOUT,
        }
        options[:phantomjs] = File.absolute_path(browser_cfg[:binary_path]) if browser_cfg.include?(:binary_path)
        options[:phantomjs_options].push('--cookies-file=%s' % File.absolute_path(browser_cfg[:cookies_path])) if browser_cfg.include?(:cookies_path)
        options[:timeout] = browser_cfg[:timeout] if browser_cfg.include?(:timeout)
        options[:phantomjs_options].concat([*browser_cfg.fetch(:phantomjs_options, [])])
        Capybara.register_driver(:poltergeist) do |app|
          driver = Capybara::Poltergeist::Driver.new(app, options)
          driver.add_header('User-Agent', browser_cfg[:user_agent]) if browser_cfg.include?(:user_agent)
          driver
        end
        dm.browser = Capybara::Session.new(:poltergeist)
      when :webkit
        dm.browser = Capybara::Session.new(:webkit)
      else
        raise ConfigEntryError, 'unsupported browser webdriver'
    end
    logger.debug { 'Browser [%s] was set up.' % browser.mode }
    browser
  end

  def signed_in?(address)
    browser.find(:id, 'BodyPlaceholder_ClaimPanel').find(:id, 'SignedInPaymentAddress').value == address
  rescue Capybara::ElementNotFound
    false
  end

  def sign_in(address)
    browser.driver.set_cookie('user', "PaymentAddress=#{address}")
    browser.visit(browser.current_url)
    unless signed_in?(address)
      logger.warn { 'Signing in as address [%s] failure. Unknown reason.' % address }
      raise Plunder::SigningInError, 'signing in failure'
    end
    logger.info { 'Signing in as address [%s] success.' % address }
    true
  end

  def claim(url, address)
    browser.visit(url)
    logger.debug { 'Claiming URL [%s] loaded.' % url }
    unless signed_in?(address)
      logger.debug { 'Not signed in as address [%s].' % address }
      sign_in(address)
    end
    dm.sleep_rand(2.0..4.0)
    browser.find(:id, 'SubmitButton').click
    logger.debug { 'Beginning to perform claim for [%s].' % address }
    solve_captcha
    grab_claim_results(address)
    true
  end

  private

  def solve_captcha
    dm.sleep_rand(4.0..6.0)
    dm.captcha_solver.solve #TODO: Referesh & retry on error.
  end

  def grab_claim_results(address)
    md = /\Abalance:\ ([0-9]+(?:\.[0-9]+)?)\ (.+)\z/.match(browser.find(:id, 'AccountBalanceLabel')[:title])
    raise AfterClaimingError, 'cannot read account balance' unless md
    balance, unit = md[1].to_d, md[2]
    claim_results = browser.find_all(:css, '#BodyPlaceholder_SuccessfulClaimPanel .success-message-panel').map(&:text)
    raise AfterClaimingError, 'invalid claim results' unless claim_results.size == 4
    claim_results.map! { |cr| ClaimResult.new(cr, unit) }
    raise AfterClaimingError, 'invalid claim results' unless claim_results[0].unit == unit && claim_results.last(3).all? { |cr| cr.unit == '%' }
    claimed = claim_results[0].amount
    bonus = claim_results.last(3).map(&:amount).reduce(:+)
    granted = (claimed * (100.to_d + bonus.to_d) / 100.to_d).no_frac_to_i
    claimed, bonus, granted = [claimed, bonus, granted].map { |n| (n.is_a?(Fixnum) ? '%d' : '%.2f') % n }
    logger.info { 'Successful claim. [%s %s] claimed + [%s %%] bonuses = [%s %s] granted to address [%s].' %
        [claimed, unit, bonus, granted, unit, address] }
  rescue Capybara::ElementNotFound
    raise AfterClaimingError, 'cannot grab claim result because some element not found'
  end
end
