module ScenariosHelper
  def format_money(value)
    number_to_currency(value, precision: 0)
  end

  def format_multiple(value)
    "%.2fx" % value
  end

  def stage_label(stage)
    case stage.to_s
    when "incubation" then "Incubation"
    when "post_seed" then "Post-Seed"
    when "post_a" then "Post-Series A"
    when "post_b" then "Post-Series B"
    else stage.to_s.titleize
    end
  end

  def outcome_color(outcome)
    case outcome.to_s
    when "exited" then "text-signal-green"
    when "failed" then "text-signal-red"
    else "text-ash"
    end
  end

  def outcome_badge_bg(outcome)
    case outcome.to_s
    when "exited" then "bg-signal-green/15 text-signal-green border-signal-green/30"
    when "failed" then "bg-signal-red/15 text-signal-red border-signal-red/30"
    else "bg-ash/15 text-ash border-ash/30"
    end
  end

  def waterfall_keys_label(key)
    case key.to_s
    when "ss1" then "SS1 LLC"
    when "consortium" then "Consortium"
    when "advisory" then "Advisory"
    when "alloy" then "Alloy Partners"
    when "founders" then "Founders"
    when "seed" then "Seed Investors"
    when "series_a" then "Series A Investors"
    when "series_b" then "Series B Investors"
    else key.to_s.titleize
    end
  end
end
