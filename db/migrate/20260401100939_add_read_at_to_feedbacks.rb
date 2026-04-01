class AddReadAtToFeedbacks < ActiveRecord::Migration[8.1]
  def change
    add_column :feedbacks, :read_at, :datetime
  end
end
