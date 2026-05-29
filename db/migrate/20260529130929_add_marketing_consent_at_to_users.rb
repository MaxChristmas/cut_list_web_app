class AddMarketingConsentAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :marketing_consent_at, :datetime
  end
end
