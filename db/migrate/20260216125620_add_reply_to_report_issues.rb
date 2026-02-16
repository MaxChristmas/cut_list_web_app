class AddReplyToReportIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :report_issues, :reply_body, :text
    add_column :report_issues, :replied_at, :datetime
    add_reference :report_issues, :replied_by, null: true, foreign_key: { to_table: :admin_users }
  end
end
