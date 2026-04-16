class CapTableController < ApplicationController
  def show
    @calculator = CapTableCalculator.new
    @result = @calculator.compute
    @variables = Variable.all.index_by(&:key)
  end

  def update_variable
    variable = Variable.find(params[:id])
    variable.update!(value: params[:value])

    sync_consortium_members if variable.key == "consortium_members"

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

  def sync_consortium_members
    target = Variable.val("consortium_members").to_i
    current = Entity.where(entity_type: "consortium")
    current_count = current.count

    if target > current_count
      # Add new members
      max_pos = Entity.maximum(:position) || 0
      (current_count + 1..target).each do |n|
        max_pos += 1
        Entity.create!(
          name: "Member #{n}",
          entity_type: "consortium",
          investment: 0,
          finders_fee_count: 0,
          position: max_pos
        )
      end
      # Push non-consortium entities down so members stay at the top
      reorder_entities
    elsif target < current_count
      # Remove excess members (from the end, only those with zero investment)
      removable = current.order(position: :desc).limit(current_count - target)
      removable.each { |e| e.destroy if e.investment.to_i.zero? }
      reorder_entities
    end
  end

  def reorder_entities
    pos = 1
    Entity.where(entity_type: "consortium").order(:position).each do |e|
      e.update_column(:position, pos)
      pos += 1
    end
    Entity.where.not(entity_type: "consortium").order(:position).each do |e|
      e.update_column(:position, pos)
      pos += 1
    end
  end

  def entity_params
    params.require(:entity).permit(:name, :investment, :finders_fee_count)
  end
end
