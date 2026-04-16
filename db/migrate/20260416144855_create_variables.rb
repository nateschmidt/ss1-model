class CreateVariables < ActiveRecord::Migration[8.0]
  def change
    create_table :variables do |t|
      t.string :key
      t.string :label
      t.decimal :value, precision: 15, scale: 4
      t.string :description

      t.timestamps
    end
    add_index :variables, :key, unique: true
  end
end
