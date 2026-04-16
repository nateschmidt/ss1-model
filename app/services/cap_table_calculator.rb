class CapTableCalculator
  attr_reader :variables, :entities

  def initialize
    @variables = load_variables
    @entities = Entity.ordered.to_a
  end

  def compute
    rows = @entities.map { |entity| compute_row(entity) }

    allocated = rows.sum { |r| r[:total_before_pool] }
    option_pool = var(:founders_option_pool)
    alloy_pct = [100.0 - allocated - option_pool, 0].max

    rows.each do |row|
      row[:alloy_equity] = alloy_pct if row[:entity].operator?
    end

    apply_option_pool_scaling(rows, option_pool)

    {
      rows: rows,
      option_pool: option_pool,
      option_pool_exercised: var(:founders_option_pool_exercised),
      alloy_equity: alloy_pct
    }
  end

  private

  def load_variables
    Variable.all.each_with_object({}) do |v, hash|
      hash[v.key] = v.value.to_f
    end
  end

  def var(key)
    @variables[key.to_s] || 0
  end

  def compute_row(entity)
    advisory = compute_advisory(entity)
    finders  = compute_finders_fee(entity)
    pooled   = compute_pooled(entity)
    preferred = compute_preferred(entity)

    {
      entity: entity,
      investment: entity.investment.to_f,
      advisory: advisory,
      finders_fee: finders,
      pooled: pooled,
      adv_plus_pooled: advisory + finders + pooled,
      preferred: preferred,
      alloy_equity: 0.0,
      total_before_pool: advisory + finders + pooled + preferred,
      total: 0.0 # filled after scaling
    }
  end

  def compute_advisory(entity)
    return 0.0 unless entity.consortium? && entity.investment.to_f > 0

    ratio = var(:investment_advisory_ratio)
    (entity.investment.to_f / 1_000_000.0) * ratio
  end

  def compute_finders_fee(entity)
    return 0.0 if entity.finders_fee_count.to_i.zero?

    total_companies = [var(:total_companies), 1].max
    fee_pct = var(:finders_fee)
    (entity.finders_fee_count.to_i.to_f / total_companies) * fee_pct
  end

  def compute_pooled(entity)
    return 0.0 unless entity.consortium?

    members = [var(:consortium_members), 1].max
    var(:pooled_consortium) / members
  end

  def compute_preferred(entity)
    return 0.0 if entity.investment.to_f.zero?
    return 0.0 if entity.operator?

    fund = [var(:fund_size), 1].max
    (entity.investment.to_f / fund) * 20.0
  end

  def apply_option_pool_scaling(rows, option_pool)
    exercised_pct = var(:founders_option_pool_exercised)
    exercised = option_pool * (exercised_pct / 100.0)
    unexercised = option_pool - exercised

    # When option pool is partially exercised, the unexercised portion
    # drops off and everyone's effective ownership scales up proportionally.
    # The "real" total is 100% - unexercised portion.
    real_total = 100.0 - unexercised

    @nominal_option_pool = exercised

    rows.each do |row|
      before = row[:total_before_pool] + row[:alloy_equity]
      row[:nominal_total] = before
      if real_total > 0
        row[:total] = (before / real_total) * 100.0
      else
        row[:total] = 0.0
      end
    end

    if real_total > 0
      @effective_option_pool = (exercised / real_total) * 100.0
    else
      @effective_option_pool = 0.0
    end
  end

  public

  def effective_option_pool
    @effective_option_pool || 0.0
  end

  def nominal_option_pool
    @nominal_option_pool || 0.0
  end
end
