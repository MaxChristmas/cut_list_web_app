class AddInternalToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :internal, :boolean, default: false, null: false
  end
end
