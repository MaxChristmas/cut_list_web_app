class AddScanTrackingToOptimizations < ActiveRecord::Migration[8.1]
  def change
    add_reference :optimizations, :scan_token, null: true, foreign_key: true
    add_column :scan_tokens, :submitted_pieces, :jsonb
  end
end
