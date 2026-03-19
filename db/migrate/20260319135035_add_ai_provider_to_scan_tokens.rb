class AddAiProviderToScanTokens < ActiveRecord::Migration[8.1]
  def change
    add_column :scan_tokens, :ai_provider, :string, default: "anthropic"
  end
end
