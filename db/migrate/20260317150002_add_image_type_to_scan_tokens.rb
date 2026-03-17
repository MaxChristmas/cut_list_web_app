class AddImageTypeToScanTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :scan_tokens, :image_type, :string
  end
end
