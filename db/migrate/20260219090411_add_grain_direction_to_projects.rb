class AddGrainDirectionToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :grain_direction, :string, default: "none", null: false
  end
end
