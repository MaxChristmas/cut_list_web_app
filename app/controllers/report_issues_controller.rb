class ReportIssuesController < ApplicationController
  def create
    report = ReportIssue.new(body: params.require(:report_issue).permit(:body)[:body])
    report.user = current_user if user_signed_in?
    report.save!

    head :created
  rescue ActiveRecord::RecordInvalid
    head :unprocessable_entity
  end
end
