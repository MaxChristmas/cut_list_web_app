class AddTemplateToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :template, :boolean, default: false, null: false
  end
end
