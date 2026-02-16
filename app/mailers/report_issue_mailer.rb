class ReportIssueMailer < ApplicationMailer
  def reply(report_issue)
    @report_issue = report_issue
    mail(to: report_issue.user.email, subject: "Re: Your report ##{report_issue.id}")
  end
end
