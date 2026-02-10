class AddTokenToProjectsAndMakeUserOptional < ActiveRecord::Migration[8.1]
  def change
    change_column_null :projects, :user_id, true
    add_column :projects, :token, :string, null: false
    add_index :projects, :token, unique: true
  end
end
