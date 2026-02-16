class AddPlanExpiresAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :plan_expires_at, :datetime
  end
end
