class DeploymentScheduler
  # Revenue Alloy receives per company per month from the fund
  REVENUE_PER_COMPANY = 75_000

  # Team: 2 zero-to-one founders, can run 2 companies concurrently
  TEAM_CAPACITY = 2
  TEAM_ANNUAL_COST = 600_000 # $300K x 2 founders, fully burdened

  # Consortium liaison: handles up to 4 companies
  LIAISON_CAPACITY = 4
  LIAISON_ANNUAL_COST = 100_000

  # One-time costs per company launch
  LAUNCH_FIXED_COST = 10_000 # legal, incorporation, setup

  # Monthly recurring per active company
  MONTHLY_SAAS_PER_COMPANY = 750 # hosting, tools, analytics

  # Per-company misc costs (incidentals, cloud, marketing tests, etc.)
  MONTHLY_MISC_PER_COMPANY = 2_500

  # Shared monthly costs (outside consultants, dev shop retainer, etc.)
  MONTHLY_SHARED_SERVICES = 8_000

  # Alloy overhead allocated to SS1 while any company is active
  MONTHLY_OVERHEAD = 15_000 # design, sales support, internal resources

  def initialize(companies:, ramp_months: 2, launch_cadence: 2,
                 monthly_misc_per_company: MONTHLY_MISC_PER_COMPANY,
                 monthly_shared_services: MONTHLY_SHARED_SERVICES)
    @companies = companies
    @ramp_months = ramp_months
    @launch_cadence = launch_cadence
    @monthly_misc_per_company = monthly_misc_per_company
    @monthly_shared_services = monthly_shared_services
  end

  def schedule
    queue = @companies.dup
    active = []
    completed = []
    timeline = []

    next_planned = @ramp_months + 1
    peak_concurrent = 0
    peak_teams = 1

    month = 1
    while month <= 72 # 6-year safety cap
      launched = []
      ended = []

      # 1. End companies that finish this month
      finishing = active.select { |a| a[:end_month] == month }
      finishing.each do |a|
        active.delete(a)
        completed << a
        ended << a[:company][:number]
      end

      # 2. Recycle: if a company just ended and there's a queued company,
      #    launch immediately on the freed slot (bypasses cadence)
      recycled = 0
      if finishing.any? && queue.any?
        finishing.size.times do
          break if queue.empty?
          co = queue.shift
          entry = launch_entry(co, month)
          active << entry
          launched << co[:number]
          recycled += 1
        end
      end

      # 3. Planned cadence launch (only if we didn't just recycle)
      if month >= next_planned && queue.any? && recycled == 0
        co = queue.shift
        entry = launch_entry(co, month)
        active << entry
        launched << co[:number]
        next_planned = month + @launch_cadence
      end

      # 4. Calculate team and liaison needs
      concurrent = active.size
      peak_concurrent = [peak_concurrent, concurrent].max

      teams_now = concurrent > 0 ? [(concurrent.to_f / TEAM_CAPACITY).ceil, 1].max : 0
      peak_teams = [peak_teams, teams_now].max
      incremental_teams = [teams_now - 1, 0].max # first team is internal

      liaisons_now = concurrent > 0 ? [(concurrent.to_f / LIAISON_CAPACITY).ceil, 1].max : 0
      incremental_liaisons = [liaisons_now - 1, 0].max # first is internal

      # 5. Costs and revenue
      revenue = concurrent * REVENUE_PER_COMPANY

      team_cost = incremental_teams * (TEAM_ANNUAL_COST / 12.0)
      liaison_cost = incremental_liaisons * (LIAISON_ANNUAL_COST / 12.0)
      launch_cost = launched.size * LAUNCH_FIXED_COST
      saas_cost = concurrent * MONTHLY_SAAS_PER_COMPANY
      misc_cost = concurrent * @monthly_misc_per_company
      shared_cost = concurrent > 0 ? @monthly_shared_services : 0
      overhead = concurrent > 0 ? MONTHLY_OVERHEAD : 0

      total_cost = team_cost + liaison_cost + launch_cost + saas_cost + misc_cost + shared_cost + overhead

      timeline << {
        month: month,
        active_ids: active.map { |a| a[:company][:number] },
        concurrent: concurrent,
        launched: launched,
        ended: ended,
        teams: teams_now,
        liaisons: liaisons_now,
        revenue: revenue.round(0),
        team_cost: team_cost.round(0),
        liaison_cost: liaison_cost.round(0),
        launch_cost: launch_cost.round(0),
        saas_cost: saas_cost.round(0),
        misc_cost: misc_cost.round(0),
        shared_cost: shared_cost.round(0),
        overhead: overhead.round(0),
        total_cost: total_cost.round(0),
        net: (revenue - total_cost).round(0),
      }

      # Stop when everything is done
      break if queue.empty? && active.empty? && month > @ramp_months + 1

      month += 1
    end

    # Cumulative totals
    cum_rev = 0
    cum_cost = 0
    timeline.each do |t|
      cum_rev += t[:revenue]
      cum_cost += t[:total_cost]
      t[:cumulative_revenue] = cum_rev
      t[:cumulative_cost] = cum_cost
      t[:cumulative_net] = cum_rev - cum_cost
    end

    # Break-even month
    breakeven = timeline.find { |t| t[:cumulative_net] > 0 }&.dig(:month)

    # Build company schedule for Gantt chart
    all_scheduled = completed + active
    gantt = all_scheduled.sort_by { |a| a[:start_month] }.map do |a|
      {
        number: a[:company][:number],
        start_month: a[:start_month],
        end_month: a[:end_month],
        duration: a[:end_month] - a[:start_month],
        outcome: a[:company][:outcome],
      }
    end

    {
      timeline: timeline,
      gantt: gantt,
      total_months: timeline.last&.dig(:month) || 0,
      peak_concurrent: peak_concurrent,
      peak_teams: peak_teams,
      breakeven_month: breakeven,
      total_revenue: cum_rev,
      total_cost: cum_cost,
      total_net: cum_rev - cum_cost,
      companies_scheduled: all_scheduled.size,
    }
  end

  private

  def launch_entry(company, month)
    {
      company: company,
      start_month: month,
      end_month: month + company[:months_active],
    }
  end
end
