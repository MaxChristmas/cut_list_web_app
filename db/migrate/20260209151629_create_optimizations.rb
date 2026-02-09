class CreateOptimizations < ActiveRecord::Migration[8.1]
  def change
    create_table :optimizations do |t|
      t.references :project, null: false, foreign_key: true
      t.jsonb :result
      t.decimal :efficiency
      t.integer :sheets_count
      t.string :status

      t.timestamps
    end
  end
end
