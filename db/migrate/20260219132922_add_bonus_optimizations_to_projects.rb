class AddBonusOptimizationsToProjects < ActiveRecord::Migration[8.1]
  def change
    add_column :projects, :bonus_optimizations, :integer, default: 0, null: false
  end
end
