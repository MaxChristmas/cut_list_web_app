class AddCutDirectionToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :cut_direction, :string, default: "auto", null: false
  end
end
