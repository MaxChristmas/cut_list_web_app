class AddUsageToScanTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :scan_tokens, :input_tokens, :integer
    add_column :scan_tokens, :output_tokens, :integer
    add_column :scan_tokens, :cost_usd, :decimal, precision: 8, scale: 4
  end
end
