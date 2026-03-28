module Admin
  class DashboardController < BaseController
    def index
      public = User.public_users

      @total_users = public.count
      @new_users_30d = public.where("created_at >= ?", 30.days.ago).count
      @total_projects = Project.where(user_id: public.select(:id)).count
      @avg_projects_per_user = @total_users.zero? ? 0 : (@total_projects.to_f / @total_users).round(1)
      @total_optimizations = Optimization.where(project_id: Project.where(user_id: public.select(:id)).select(:id)).count
      @avg_optimizations_per_project_per_user = @total_users.zero? ? 0 : (@total_optimizations.to_f / @total_users).round(1)
      @users_by_plan = public.group(:plan).count

      # Paid users breakdown (non-expired paid plans only)
      paid = public.where.not(plan: "free")
                   .where("plan_expires_at IS NULL OR plan_expires_at > ?", Time.current)
      @paid_users_total = paid.count
      @paid_subscription_count = paid.where.not(stripe_subscription_id: nil).count
      @paid_one_shot_count = paid.where(stripe_subscription_id: nil)
                                 .where.not(plan_expires_at: nil).count
      @paid_coupon_count = paid.where(stripe_subscription_id: nil)
                               .where(plan_expires_at: nil)
                               .where(id: CouponRedemption.select(:user_id)).count

      @recent_reports = ReportIssue.order(created_at: :desc).limit(5).includes(:user)

      # Device breakdown
      @device_counts = public.where.not(last_sign_in_device: nil).group(:last_sign_in_device).count

      # New users per day over the last 15 days
      start_date = 14.days.ago.to_date
      counts = public.where("created_at >= ?", start_date.beginning_of_day)
                     .group("DATE(created_at)")
                     .count
      @new_users_labels = (start_date..Date.current).map { |d| d.strftime("%d/%m") }
      @new_users_data = (start_date..Date.current).map { |d| counts[d] || 0 }

      # Pieces distribution: users grouped by piece count (per tens) from last optimization
      public_project_ids = Project.where(user_id: public.select(:id)).select(:id)
      last_opt_ids = Optimization
        .select("DISTINCT ON (project_id) id")
        .where(project_id: public_project_ids)
        .order(:project_id, created_at: :desc)
      last_opts = Optimization.where(id: last_opt_ids).includes(:project)

      bucket_users = Hash.new { |h, k| h[k] = Set.new }
      last_opts.each do |opt|
        next unless opt.result.is_a?(Hash) && opt.result["sheets"].is_a?(Array)
        pieces_count = opt.result["sheets"].sum { |s| s["placements"]&.size || 0 }
        next if pieces_count > 5000
        bucket = (pieces_count / 10) * 10
        bucket_users[bucket].add(opt.project.user_id)
      end

      sorted_buckets = bucket_users.keys.sort
      @pieces_labels = sorted_buckets.map { |b| "#{b}-#{b + 9}" }
      @pieces_data = sorted_buckets.map { |b| bucket_users[b].size }
    end
  end
end
