module Kernel
  def inline_rescue(exception_to_ignore = StandardError, default_value = nil)
    yield
  rescue Exception => e
    raise unless e.is_a?(exception_to_ignore)
    default_value
  end
end