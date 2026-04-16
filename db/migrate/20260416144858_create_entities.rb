class CreateEntities < ActiveRecord::Migration[8.0]
  def change
    create_table :entities do |t|
      t.string :name
      t.string :entity_type
      t.decimal :investment, precision: 15, scale: 2, default: 0
      t.integer :finders_fee_count, default: 0
      t.integer :position, default: 0

      t.timestamps
    end
  end
end
