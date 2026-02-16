class AddPageUrlToReportIssues < ActiveRecord::Migration[8.1]
  def change
    add_column :report_issues, :page_url, :string
  end
end
