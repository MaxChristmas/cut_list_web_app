class CreateCoupons < ActiveRecord::Migration[8.1]
  def change
    create_table :coupons do |t|
      t.string :code, null: false
      t.string :plan, null: false
      t.integer :duration_days, null: false
      t.datetime :expires_at
      t.integer :max_uses
      t.integer :uses_count, default: 0, null: false
      t.timestamps
    end
    add_index :coupons, :code, unique: true

    create_table :coupon_redemptions do |t|
      t.references :coupon, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.timestamps
    end
    add_index :coupon_redemptions, [ :coupon_id, :user_id ], unique: true
  end
end
