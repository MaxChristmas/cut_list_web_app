class AddScanLimitOverrideToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :scan_limit_override, :integer
  end
end
