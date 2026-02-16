class ReportIssueMailerPreview < ActionMailer::Preview
  def reply
    report_issue = ReportIssue.last

    # Use a fake reply_body if the record hasn't been replied to yet
    unless report_issue.replied?
      report_issue.reply_body = "Thank you for reporting this issue. We've identified the problem and a fix will be deployed shortly."
    end

    ReportIssueMailer.reply(report_issue)
  end
end
