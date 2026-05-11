class RenameFeedbacksReadAtToTreatedAt < ActiveRecord::Migration[8.1]
  def change
    rename_column :feedbacks, :read_at, :treated_at
    add_index :feedbacks, :treated_at
  end
end
