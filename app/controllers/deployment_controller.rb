class DeploymentController < ApplicationController
  def show
    @ramp_months = (params[:ramp_months] || 2).to_i
    @launch_cadence = (params[:launch_cadence] || 2).to_i
    @misc_per_company = (params[:misc_per_company] || 2500).to_i
    @shared_services = (params[:shared_services] || 8000).to_i
    @scenario_label = session[:scenario_label]
    @has_scenario = session[:scenario_companies].present?
  end

  def generate
    @ramp_months = (params[:ramp_months] || 2).to_i
    @launch_cadence = (params[:launch_cadence] || 2).to_i
    @misc_per_company = (params[:misc_per_company] || 2500).to_i
    @shared_services = (params[:shared_services] || 8000).to_i
    @scenario_label = session[:scenario_label]

    # Rebuild company data from session
    raw_companies = session[:scenario_companies]
    unless raw_companies.present?
      return render turbo_stream: turbo_stream.replace("deployment-results",
        html: '<turbo-frame id="deployment-results"><div class="text-center py-16 text-signal-red"><p class="text-lg">No scenario data found. Please run a scenario first.</p></div></turbo-frame>')
    end

    companies = raw_companies.map do |c|
      { number: c["number"], months_active: c["months_active"], outcome: c["outcome"].to_sym }
    end
    @fund_size = session[:scenario_fund_size] || Variable.val("fund_size").to_f

    scheduler = DeploymentScheduler.new(
      companies: companies,
      ramp_months: @ramp_months,
      launch_cadence: @launch_cadence,
      monthly_misc_per_company: @misc_per_company,
      monthly_shared_services: @shared_services
    )
    @schedule = scheduler.schedule

    render turbo_stream: turbo_stream.replace("deployment-results", partial: "deployment/results")
  end
end
