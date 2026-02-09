class CreateProjects < ActiveRecord::Migration[8.1]
  def change
    create_table :projects do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.integer :sheet_width
      t.integer :sheet_height
      t.boolean :allow_rotation

      t.timestamps
    end
  end
end
