class AddDefaultAndIndexToPlan < ActiveRecord::Migration[8.1]
  def change
    change_column_default :users, :plan, from: nil, to: "free"
    change_column_null :users, :plan, false, "free"
    add_index :users, :plan
  end
end
