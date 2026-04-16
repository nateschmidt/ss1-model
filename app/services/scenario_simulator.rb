class ScenarioSimulator
  MONTHLY_BURN = 75_000
  MAX_INCUBATION_MONTHS = 18

  RISK_PROFILES = {
    conservative: {
      incubation_survival: 0.40,
      post_seed:  { die: 0.30, exit: 0.20, advance: 0.50 },
      post_a:     { die: 0.20, exit: 0.30, advance: 0.50 },
      post_b:     { die: 0.15, exit: 0.85 },
      exit_values: {
        small:  { min: 8_000_000,   max: 50_000_000 },
        medium: { min: 40_000_000,  max: 175_000_000 },
        large:  { min: 100_000_000, max: 500_000_000 },
      },
    },
    moderate: {
      incubation_survival: 0.55,
      post_seed:  { die: 0.20, exit: 0.15, advance: 0.65 },
      post_a:     { die: 0.15, exit: 0.25, advance: 0.60 },
      post_b:     { die: 0.10, exit: 0.90 },
      exit_values: {
        small:  { min: 15_000_000,  max: 75_000_000 },
        medium: { min: 50_000_000,  max: 250_000_000 },
        large:  { min: 150_000_000, max: 750_000_000 },
      },
    },
    aggressive: {
      incubation_survival: 0.70,
      post_seed:  { die: 0.10, exit: 0.10, advance: 0.80 },
      post_a:     { die: 0.10, exit: 0.20, advance: 0.70 },
      post_b:     { die: 0.05, exit: 0.95 },
      exit_values: {
        small:  { min: 20_000_000,  max: 100_000_000 },
        medium: { min: 75_000_000,  max: 400_000_000 },
        large:  { min: 200_000_000, max: 1_000_000_000 },
      },
    },
  }.freeze

  # Founder pool exercise — independent of risk tolerance.
  # Skew of 2.5 means ~50% of companies give away 80-100% of the pool,
  # with a tail down to 0% for companies Alloy operates long-term.
  FOUNDER_POOL_SKEW = 2.5

  SEED_RANGE       = (1_500_000..3_500_000)
  SEED_DILUTION    = (20..25)
  SERIES_A_RANGE   = (10_000_000..25_000_000)
  SERIES_A_DILUTION = (20..25)
  SERIES_B_RANGE   = (25_000_000..60_000_000)
  SERIES_B_DILUTION = (15..20)

  def initialize(risk_level: :moderate, num_simulations: 500)
    @risk_level = risk_level.to_sym
    @profile = RISK_PROFILES[@risk_level]
    @num_simulations = num_simulations
    @vars = load_variables
  end

  def run
    simulations = @num_simulations.times.map { simulate_portfolio }
    aggregate(simulations)
  end

  private

  def load_variables
    raw = Variable.pluck(:key, :value).to_h
    {
      fund_size: (raw["fund_size"] || 7_500_000).to_f,
      num_companies: (raw["total_companies"] || 7).to_i,
      pooled_consortium: (raw["pooled_consortium"] || 5).to_f,
      consortium_members: (raw["consortium_members"] || 7).to_i,
      finders_fee: (raw["finders_fee"] || 2).to_f,
      founders_option_pool: (raw["founders_option_pool"] || 60).to_f,
    }
  end

  # ── Portfolio simulation ──────────────────────────────────────────

  MAX_COMPANIES = 25 # safety cap
  MIN_FUND_TO_LAUNCH = 1_000_000

  def simulate_portfolio
    fund_remaining = @vars[:fund_size]
    companies = []
    i = 0

    while fund_remaining >= MIN_FUND_TO_LAUNCH && i < MAX_COMPANIES
      i += 1
      company = simulate_company(i, fund_remaining)
      fund_remaining -= company[:capital_deployed]
      company[:fund_remaining] = fund_remaining
      companies << company
    end

    total_returned = companies.sum { |c| c[:fund_return] }
    {
      companies: companies,
      total_deployed: companies.sum { |c| c[:capital_deployed] },
      total_returned: total_returned,
      tvpi: @vars[:fund_size] > 0 ? total_returned / @vars[:fund_size] : 0,
      companies_launched: companies.size,
      companies_exited: companies.count { |c| c[:outcome] == :exited },
      companies_failed: companies.count { |c| c[:outcome] == :failed },
    }
  end

  # ── Single company simulation ─────────────────────────────────────

  def simulate_company(number, available_capital)
    max_months = [available_capital / MONTHLY_BURN, MAX_INCUBATION_MONTHS].min.floor

    # Does it survive incubation?
    unless rand < @profile[:incubation_survival]
      fail_ceil = [max_months, 12].min
      months = fail_ceil <= 2 ? fail_ceil : rand(2..fail_ceil)
      capital = months * MONTHLY_BURN
      return build_company(number, :failed, :incubation, months, capital, 0, nil, [])
    end

    # Survived incubation — determine founder allocation first,
    # because it drives how long Alloy operates the company.
    pool = @vars[:founders_option_pool]
    exercise_rate = 1.0 - (rand ** FOUNDER_POOL_SKEW)
    founders_pct = pool * exercise_rate

    # If founders get less than half the pool, Alloy is running it
    # themselves and will use the full incubation period.
    if exercise_rate < 0.5
      months = max_months
    else
      # Founders came in — Alloy hands off earlier
      low = [6, max_months].min
      months = low >= max_months ? max_months : rand(low..max_months)
    end
    capital = months * MONTHLY_BURN

    cap = build_initial_cap_table(capital, founders_pct)
    rounds = []

    # ── Seed Round ──
    seed_amt = rand(SEED_RANGE)
    seed_dil = rand(SEED_DILUTION) / 100.0
    dilute!(cap, seed_dil)
    cap[:seed] = pref_entry(seed_dil * 100, seed_amt)
    rounds << round_info("Seed", seed_amt, seed_dil * 100)

    outcome = stage_gate(@profile[:post_seed])
    return build_company(number, outcome[:result], :post_seed, months, capital, outcome[:exit], cap, rounds, founder_pool_pct: founders_pct) unless outcome[:advance]

    # ── Series A ──
    a_amt = rand(SERIES_A_RANGE)
    a_dil = rand(SERIES_A_DILUTION) / 100.0
    dilute!(cap, a_dil)
    cap[:series_a] = pref_entry(a_dil * 100, a_amt)
    rounds << round_info("Series A", a_amt, a_dil * 100)

    outcome = stage_gate(@profile[:post_a])
    return build_company(number, outcome[:result], :post_a, months, capital, outcome[:exit], cap, rounds, founder_pool_pct: founders_pct) unless outcome[:advance]

    # ── Series B ──
    b_amt = rand(SERIES_B_RANGE)
    b_dil = rand(SERIES_B_DILUTION) / 100.0
    dilute!(cap, b_dil)
    cap[:series_b] = pref_entry(b_dil * 100, b_amt)
    rounds << round_info("Series B", b_amt, b_dil * 100)

    outcome = stage_gate(@profile[:post_b])
    exit_val = outcome[:advance] ? random_exit(:large) : outcome[:exit]
    result = outcome[:advance] ? :exited : outcome[:result]
    build_company(number, result, :post_b, months, capital, exit_val, cap, rounds, founder_pool_pct: founders_pct)
  end

  def stage_gate(profile)
    roll = rand
    if roll < profile[:die]
      { advance: false, result: :failed, exit: 0 }
    elsif roll < profile[:die] + (profile[:exit] || 0)
      size = case profile
             when @profile[:post_seed] then :small
             when @profile[:post_a] then :medium
             else :large
             end
      { advance: false, result: :exited, exit: random_exit(size) }
    else
      { advance: true, result: nil, exit: nil }
    end
  end

  # ── Cap table helpers ─────────────────────────────────────────────

  def build_initial_cap_table(capital, founders_pct)
    pool = @vars[:founders_option_pool]
    pooled = @vars[:pooled_consortium]
    finders = @vars[:finders_fee]

    # Simplified: average advisory across the portfolio
    avg_advisory = 1.5
    common_pct = pooled + avg_advisory + finders
    alloy_pct = [100.0 - 20.0 - pool - common_pct, 0].max
    unexercised = pool - founders_pct

    {
      ss1:          pref_entry(20.0, capital),
      consortium:   common_entry(pooled),
      advisory:     common_entry(avg_advisory + finders),
      alloy:        common_entry(alloy_pct),
      founders:     common_entry(founders_pct),
      unexercised:  { pct: unexercised, invested: 0, type: :pool },
    }
  end

  def pref_entry(pct, invested)  = { pct: pct, invested: invested, type: :preferred }
  def common_entry(pct)          = { pct: pct, invested: 0, type: :common }
  def round_info(name, amt, dil) = { name: name, amount: amt, dilution_pct: dil }

  def dilute!(cap, fraction)
    cap.each_value { |e| e[:pct] *= (1.0 - fraction) }
  end

  # ── Waterfall ─────────────────────────────────────────────────────

  def build_company(number, outcome, stage, months, capital, exit_value, cap, rounds, founder_pool_pct: nil)
    waterfall = (cap && exit_value > 0) ? calculate_waterfall(cap, exit_value) : {}
    fund_return = waterfall[:ss1] || 0

    {
      number: number,
      outcome: outcome,
      stage: stage,
      months_active: months,
      capital_deployed: capital,
      exit_value: exit_value,
      fund_return: fund_return,
      cap_table: cap,
      rounds: rounds,
      waterfall: waterfall,
      founder_pool_pct: founder_pool_pct,
    }
  end

  def calculate_waterfall(cap, exit_value)
    return Hash.new(0) if exit_value <= 0

    active = cap.reject { |_, v| v[:type] == :pool }
    total_pct = active.values.sum { |v| v[:pct] }
    return Hash.new(0) if total_pct <= 0

    # Preferred classes in seniority order (most recent first)
    pref_keys = [:series_b, :series_a, :seed, :ss1].select { |k| active[k] }

    # Each preferred class decides: take 1x preference or convert to common?
    # If their as-converted share > preference, they convert.
    converting = []
    taking_pref = []

    pref_keys.each do |key|
      entry = active[key]
      as_converted = (entry[:pct] / total_pct) * exit_value
      if as_converted >= entry[:invested]
        converting << key
      else
        taking_pref << key
      end
    end

    distributions = {}
    remaining = exit_value.to_f

    # Pay preferences in seniority order
    taking_pref.each do |key|
      payout = [active[key][:invested], remaining].min
      distributions[key] = payout
      remaining -= payout
    end

    # Remaining to common + converted preferred, pro-rata
    common_keys = active.select { |_, v| v[:type] == :common }.keys + converting
    common_total = common_keys.sum { |k| active[k][:pct] }

    if common_total > 0 && remaining > 0
      common_keys.each do |key|
        share = (active[key][:pct] / common_total) * remaining
        distributions[key] = (distributions[key] || 0) + share
      end
    end

    active.each_key { |k| distributions[k] ||= 0 }
    distributions
  end

  # ── Random value helpers ──────────────────────────────────────────

  def random_exit(size)
    range = @profile[:exit_values][size]
    log_min = Math.log(range[:min].to_f)
    log_max = Math.log(range[:max].to_f)
    Math.exp(rand_float(log_min, log_max)).round
  end

  def rand_float(min, max)
    min + rand * (max - min)
  end

  # ── Aggregation ───────────────────────────────────────────────────

  def aggregate(simulations)
    sorted = simulations.sort_by { |s| s[:tvpi] }
    median = sorted[sorted.size / 2]

    n = sorted.size.to_f
    {
      risk_level: @risk_level,
      num_simulations: @num_simulations,
      fund_size: @vars[:fund_size],
      percentiles: {
        p10: pct_data(sorted, 10),
        p25: pct_data(sorted, 25),
        p50: pct_data(sorted, 50),
        p75: pct_data(sorted, 75),
        p90: pct_data(sorted, 90),
      },
      median_simulation: median,
      avg_tvpi: (sorted.sum { |s| s[:tvpi] } / n).round(2),
      avg_launched: (sorted.sum { |s| s[:companies_launched] } / n).round(1),
      avg_exited: (sorted.sum { |s| s[:companies_exited] } / n).round(1),
      avg_failed: (sorted.sum { |s| s[:companies_failed] } / n).round(1),
      avg_stakeholder_returns: stakeholder_averages(simulations),
    }
  end

  def stakeholder_averages(simulations)
    keys = [:ss1, :alloy, :founders, :consortium, :advisory, :seed, :series_a, :series_b]
    n = simulations.size.to_f

    totals = keys.each_with_object({}) { |k, h| h[k] = 0.0 }
    simulations.each do |sim|
      sim[:companies].each do |c|
        next unless c[:waterfall]
        keys.each { |k| totals[k] += (c[:waterfall][k] || 0) }
      end
    end

    {
      ss1:        (totals[:ss1] / n).round(0),
      alloy:      (totals[:alloy] / n).round(0),
      founders:   (totals[:founders] / n).round(0),
      consortium: ((totals[:consortium] + totals[:advisory]) / n).round(0),
      seed:       (totals[:seed] / n).round(0),
      series_a:   (totals[:series_a] / n).round(0),
      series_b:   (totals[:series_b] / n).round(0),
      follow_on:  ((totals[:seed] + totals[:series_a] + totals[:series_b]) / n).round(0),
    }
  end

  def pct_data(sorted, pct)
    idx = [(sorted.size * pct / 100.0).floor, sorted.size - 1].min
    s = sorted[idx]
    {
      tvpi: s[:tvpi].round(2),
      total_returned: s[:total_returned].round(0),
      companies_launched: s[:companies_launched],
      companies_exited: s[:companies_exited],
      companies_failed: s[:companies_failed],
    }
  end
end
