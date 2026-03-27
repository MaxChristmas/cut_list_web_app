class AddFeedbackDismissedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :feedback_dismissed_at, :datetime
  end
end
