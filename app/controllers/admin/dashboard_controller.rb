module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @new_users_30d = User.where("created_at >= ?", 30.days.ago).count
      @total_projects = Project.count
      @total_optimizations = Optimization.count
      @users_by_plan = User.group(:plan).count
      @recent_reports = ReportIssue.order(created_at: :desc).limit(5).includes(:user)
    end
  end
end
