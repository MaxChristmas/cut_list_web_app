class AddOptimizationsCountToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :optimizations_count, :integer, default: 0, null: false

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE projects SET optimizations_count = (
            SELECT COUNT(*) FROM optimizations WHERE optimizations.project_id = projects.id
          )
        SQL
      end
    end
  end
end
