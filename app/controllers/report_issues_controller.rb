class ReportIssuesController < ApplicationController
  before_action :authenticate_user!

  def create
    permitted = params.require(:report_issue).permit(:body, :page_url)
    report = ReportIssue.new(body: permitted[:body], page_url: permitted[:page_url])
    report.user = current_user
    report.save!

    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end
end
