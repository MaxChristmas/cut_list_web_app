module Admin
  class ReportIssuesController < BaseController
    before_action :set_report_issue, only: [ :show, :edit, :update, :destroy, :reply ]

    def index
      @report_issues = paginate(ReportIssue.includes(:user).order(created_at: :desc))
    end

    def show
    end

    def edit
    end

    def update
      if @report_issue.update(report_issue_params)
        redirect_to admin_report_issue_path(@report_issue), notice: "Report updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def reply
      reply_body = params.require(:report_issue).permit(:reply_body)[:reply_body]

      if reply_body.blank?
        redirect_to admin_report_issue_path(@report_issue), alert: "Reply body can't be blank."
        return
      end

      @report_issue.update!(reply_body: reply_body, replied_at: Time.current, replied_by: current_admin_user)
      ReportIssueMailer.reply(@report_issue).deliver_later

      redirect_to admin_report_issue_path(@report_issue), notice: "Reply sent successfully."
    end

    def destroy
      @report_issue.destroy
      redirect_to admin_report_issues_path, notice: "Report deleted successfully."
    end

    private

    def set_report_issue
      @report_issue = ReportIssue.find(params[:id])
    end

    def report_issue_params
      params.expect(report_issue: [ :body ])
    end
  end
end
