class AddProjectIdToScanTokens < ActiveRecord::Migration[8.1]
  def change
    add_reference :scan_tokens, :project, foreign_key: true, null: true
  end
end
