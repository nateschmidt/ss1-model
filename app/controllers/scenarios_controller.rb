class ScenariosController < ApplicationController
  def show
    @risk_level = params[:risk_level] || "moderate"
    @num_simulations = (params[:num_simulations] || 500).to_i
    @mode = nil
  end

  def single_run
    @risk_level = params[:risk_level] || "moderate"

    simulator = ScenarioSimulator.new(
      risk_level: @risk_level,
      num_simulations: 1
    )
    result = simulator.run
    @portfolio = result[:median_simulation]
    @fund_size = result[:fund_size]
    @vars_pool = Variable.val("founders_option_pool").to_f

    # Store for deployment schedule
    session[:scenario_companies] = @portfolio[:companies].map { |c|
      { number: c[:number], months_active: c[:months_active], outcome: c[:outcome].to_s }
    }
    session[:scenario_fund_size] = @fund_size
    session[:scenario_label] = "Single run (#{@risk_level.capitalize})"

    render turbo_stream: turbo_stream.replace("scenario-results", partial: "scenarios/results_wrapper",
      locals: { show_deployment_link: true })
  end

  def simulate
    @risk_level = params[:risk_level] || "moderate"
    @num_simulations = (params[:num_simulations] || 500).to_i

    simulator = ScenarioSimulator.new(
      risk_level: @risk_level,
      num_simulations: @num_simulations
    )
    @result = simulator.run
    @vars_pool = Variable.val("founders_option_pool").to_f

    # Store median simulation for deployment schedule
    med = @result[:median_simulation]
    session[:scenario_companies] = med[:companies].map { |c|
      { number: c[:number], months_active: c[:months_active], outcome: c[:outcome].to_s }
    }
    session[:scenario_fund_size] = @result[:fund_size]
    session[:scenario_label] = "Monte Carlo median (#{@risk_level.capitalize}, #{@num_simulations} sims)"

    render turbo_stream: turbo_stream.replace("scenario-results", partial: "scenarios/results_wrapper",
      locals: { show_deployment_link: true })
  end
end
