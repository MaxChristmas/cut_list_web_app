class AddTreatedAtToReportIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :report_issues, :treated_at, :datetime
    add_index :report_issues, :treated_at
  end
end
