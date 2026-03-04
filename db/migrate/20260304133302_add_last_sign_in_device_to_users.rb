class AddLastSignInDeviceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_sign_in_device, :string
  end
end
