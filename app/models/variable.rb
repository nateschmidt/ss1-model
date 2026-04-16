class Variable < ApplicationRecord
  validates :key, presence: true, uniqueness: true
  validates :label, presence: true

  KEYS = %w[
    fund_size
    investment_advisory_ratio
    finders_fee
    pooled_consortium
    consortium_members
    founders_option_pool
    founders_option_pool_exercised
    total_companies
  ].freeze

  def self.val(key)
    find_by(key: key)&.value || 0
  end

  def format_type
    case key
    when "fund_size"
      :currency
    when "finders_fee", "pooled_consortium", "founders_option_pool", "founders_option_pool_exercised"
      :percentage
    else
      :number
    end
  end

  def help_text
    case key
    when "investment_advisory_ratio"
      "Advisory shares earned per $1M invested by a consortium member. A ratio of 1 = 1% per $1M."
    when "finders_fee"
      "Advisory shares awarded to whoever originates the idea for a new venture."
    when "pooled_consortium"
      "Common stock split equally among all consortium members in every company launched."
    end
  end
end
