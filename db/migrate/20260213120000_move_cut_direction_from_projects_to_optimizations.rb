class MoveCutDirectionFromProjectsToOptimizations < ActiveRecord::Migration[8.1]
  def up
    add_column :optimizations, :cut_direction, :string, default: "auto", null: false

    execute <<~SQL
      UPDATE optimizations
      SET cut_direction = projects.cut_direction
      FROM projects
      WHERE optimizations.project_id = projects.id
    SQL

    remove_column :projects, :cut_direction
  end

  def down
    add_column :projects, :cut_direction, :string, default: "auto", null: false

    execute <<~SQL
      UPDATE projects
      SET cut_direction = (
        SELECT optimizations.cut_direction
        FROM optimizations
        WHERE optimizations.project_id = projects.id
        ORDER BY optimizations.created_at DESC
        LIMIT 1
      )
      WHERE EXISTS (
        SELECT 1 FROM optimizations WHERE optimizations.project_id = projects.id
      )
    SQL

    remove_column :optimizations, :cut_direction
  end
end
