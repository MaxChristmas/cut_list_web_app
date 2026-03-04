module Admin
  class DashboardController < BaseController
    def index
      @total_users = User.count
      @new_users_30d = User.where("created_at >= ?", 30.days.ago).count
      @total_projects = Project.count
      @avg_projects_per_user = @total_users.zero? ? 0 : (@total_projects.to_f / @total_users).round(1)
      @total_optimizations = Optimization.count
      @avg_optimizations_per_project_per_user = @total_users.zero? ? 0 : (@total_optimizations.to_f / @total_users).round(1)
      @users_by_plan = User.group(:plan).count
      @recent_reports = ReportIssue.order(created_at: :desc).limit(5).includes(:user)

      # Device breakdown
      @device_counts = User.where.not(last_sign_in_device: nil).group(:last_sign_in_device).count

      # New users per day over the last 15 days
      start_date = 14.days.ago.to_date
      counts = User.where("created_at >= ?", start_date.beginning_of_day)
                    .group("DATE(created_at)")
                    .count
      @new_users_labels = (start_date..Date.current).map { |d| d.strftime("%d/%m") }
      @new_users_data = (start_date..Date.current).map { |d| counts[d] || 0 }
    end
  end
end
