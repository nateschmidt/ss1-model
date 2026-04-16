class CapTableController < ApplicationController
  def show
    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)
  end

  def update_variable
    variable = Variable.find(params[:id])
    variable.update!(value: params[:value])

    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)

    render turbo_stream: turbo_stream.replace("cap-table", partial: "cap_table/table")
  end

  def update_entity
    entity = Entity.find(params[:id])
    entity.update!(entity_params)

    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)

    render turbo_stream: turbo_stream.replace("cap-table", partial: "cap_table/table")
  end

  def increment_finders_fee
    entity = Entity.find(params[:id])
    total_companies = [Variable.val("total_companies").to_i, 1].max
    new_count = [entity.finders_fee_count + 1, total_companies].min
    entity.update!(finders_fee_count: new_count)

    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)

    render turbo_stream: turbo_stream.replace("cap-table", partial: "cap_table/table")
  end

  def decrement_finders_fee
    entity = Entity.find(params[:id])
    new_count = [entity.finders_fee_count - 1, 0].max
    entity.update!(finders_fee_count: new_count)

    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)

    render turbo_stream: turbo_stream.replace("cap-table", partial: "cap_table/table")
  end

  private

  def entity_params
    params.require(:entity).permit(:name, :investment, :finders_fee_count)
  end
end
