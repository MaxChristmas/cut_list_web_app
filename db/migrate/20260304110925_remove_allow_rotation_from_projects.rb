class RemoveAllowRotationFromProjects < ActiveRecord::Migration[8.1]
  def change
    remove_column :projects, :allow_rotation, :boolean
  end
end
