class CreateReportIssues < ActiveRecord::Migration[8.0]
  def change
    create_table :report_issues do |t|
      t.references :user, null: true, foreign_key: true
      t.text :body, null: false
      t.timestamps
    end
  end
end
