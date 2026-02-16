module Admin
  class ReportIssuesController < BaseController
    before_action :set_report_issue, only: [ :show, :edit, :update, :destroy ]

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
