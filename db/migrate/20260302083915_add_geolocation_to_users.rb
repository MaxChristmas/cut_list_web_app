class AddGeolocationToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_sign_in_ip, :string
    add_column :users, :last_sign_in_country, :string
    add_column :users, :last_sign_in_city, :string
  end
end
