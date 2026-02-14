class AddEditedResultToOptimizations < ActiveRecord::Migration[8.1]
  def change
    add_column :optimizations, :edited_result, :jsonb
  end
end
