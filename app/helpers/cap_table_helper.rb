module CapTableHelper
  def format_pct(value)
    "%.2f%%" % value
  end

  def format_currency(value)
    number_to_currency(value, precision: 0)
  end

  def variable_input_step(variable)
    case variable.key
    when "fund_size"
      100_000
    when "finders_fee", "pooled_consortium"
      0.5
    when "founders_option_pool", "founders_option_pool_exercised"
      5
    else
      1
    end
  end
end
