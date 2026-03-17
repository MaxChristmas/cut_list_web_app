class CreateScanTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :scan_tokens do |t|
      t.references :user, null: false, foreign_key: true
      t.string :token, null: false
      t.string :status, null: false, default: "pending"
      t.jsonb :result
      t.datetime :expires_at, null: false

      t.timestamps
    end

    add_index :scan_tokens, :token, unique: true
    add_index :scan_tokens, :expires_at
  end
end
