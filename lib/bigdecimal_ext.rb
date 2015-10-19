require 'bigdecimal'
require 'bigdecimal/util'

class BigDecimal
  DEFAULT_STR_FORMAT = 'F'.freeze

  def to_fmt_s(fmt = DEFAULT_STR_FORMAT, *args)
    _org_to_s fmt, *args
  end

  alias_method :_org_to_s, :to_s
  alias_method :to_s, :to_fmt_s
end