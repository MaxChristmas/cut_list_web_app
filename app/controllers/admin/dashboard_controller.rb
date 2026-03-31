module Admin
  class DashboardController < BaseController
    def index
      compute_dashboard_stats
    end

    def export
      compute_dashboard_stats

      new_users_trend = @new_users_labels.zip(@new_users_data).map do |date, count|
        { date: date, count: count }
      end

      pieces_distribution = @pieces_labels.zip(@pieces_data).map do |range, users|
        { range: range, users: users }
      end

      opt_distribution = @opt_distribution_labels.zip(@opt_distribution_data).map do |range, users|
        { range: range, users: users }
      end

      payload = {
        exported_at: Time.current.iso8601,
        users: {
          total: @total_users,
          new_last_30_days: @new_users_30d,
          by_plan: @users_by_plan,
          paid: {
            total: @paid_users_total,
            subscription: @paid_subscription_count,
            one_shot: @paid_one_shot_count,
            coupon: @paid_coupon_count
          },
          devices: {
            desktop: @device_counts["desktop"] || 0,
            mobile: @device_counts["mobile"] || 0
          }
        },
        projects: {
          total: @total_projects,
          avg_per_user: @avg_projects_per_user
        },
        optimizations: {
          total: @total_optimizations,
          avg_per_user: @avg_optimizations_per_project_per_user,
          distribution_by_user: @opt_distribution_labels.zip(@opt_distribution_data).to_h
        },
        new_users_trend: new_users_trend,
        pieces_distribution: pieces_distribution,
        optimizations_distribution: opt_distribution,
        retention_cohorts: @retention_cohorts,
        paid_users_details: @paid_users_details.map do |u|
          {
            id: u[:id],
            plan: u[:plan],
            type: u[:is_subscription] ? "subscription" : "one_shot",
            signup_date: u[:signup_date]&.iso8601,
            sign_in_count: u[:sign_in_count],
            total_projects: u[:total_projects],
            total_optimizations: u[:total_optimizations],
            active_weeks: u[:active_weeks],
            last_optimization: u[:last_optimization]&.iso8601
          }
        end
      }

      filename = "dashboard_export_#{Date.current.strftime("%Y%m%d")}.json"
      send_data payload.to_json, filename: filename, type: "application/json", disposition: "attachment"
    end

    private

    def compute_dashboard_stats
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

      # Paid users detail — single LEFT JOIN query
      paid_rows = User
        .public_users
        .where.not(plan: "free")
        .where("users.plan_expires_at IS NULL OR users.plan_expires_at > ?", Time.current)
        .select(
          "users.id",
          "users.plan",
          "users.stripe_subscription_id IS NOT NULL AS is_subscription",
          "users.created_at AS signup_date",
          "users.sign_in_count",
          "COUNT(DISTINCT projects.id) AS total_projects",
          "COUNT(DISTINCT optimizations.id) AS total_optimizations",
          "COUNT(DISTINCT DATE_TRUNC('week', optimizations.created_at)) AS active_weeks",
          "MAX(optimizations.created_at) AS last_optimization"
        )
        .left_joins(projects: :optimizations)
        .group("users.id, users.plan, users.stripe_subscription_id, users.created_at, users.sign_in_count")
        .order("is_subscription DESC, total_optimizations DESC")

      @paid_users_details = paid_rows.map do |row|
        {
          id: row.id,
          plan: row.plan,
          is_subscription: row.is_subscription,
          signup_date: row.signup_date,
          sign_in_count: row.sign_in_count,
          total_projects: row.total_projects.to_i,
          total_optimizations: row.total_optimizations.to_i,
          active_weeks: row.active_weeks.to_i,
          last_optimization: row.last_optimization
        }
      end

      @paid_subscription_vs_oneshot = {
        subscription: @paid_users_details.count { |u| u[:is_subscription] },
        one_shot: @paid_users_details.count { |u| !u[:is_subscription] }
      }

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

      # Optimizations per user distribution: single JOIN query, bucket in Ruby
      opt_counts_by_user = User
        .public_users
        .left_joins(projects: :optimizations)
        .group("users.id")
        .count("optimizations.id")

      opt_buckets = { "0" => 0, "1" => 0, "2-5" => 0, "6-10" => 0, "11-25" => 0, "26-50" => 0, "51-100" => 0, "100+" => 0 }
      opt_counts_by_user.each_value do |n|
        bucket = case n
                 when 0       then "0"
                 when 1       then "1"
                 when 2..5    then "2-5"
                 when 6..10   then "6-10"
                 when 11..25  then "11-25"
                 when 26..50  then "26-50"
                 when 51..100 then "51-100"
                 else              "100+"
                 end
        opt_buckets[bucket] += 1
      end

      @opt_distribution_labels = opt_buckets.keys
      @opt_distribution_data   = opt_buckets.values

      # Cohort retention table — last 6 months of signups
      # Single query: for each public user, get their signup date and
      # the earliest optimization date they ever created (across all projects).
      today = Date.current
      cohort_start = 6.months.ago.beginning_of_month

      retention_rows = User
        .public_users
        .where("users.created_at >= ?", cohort_start)
        .select(
          "users.id",
          "DATE_TRUNC('month', users.created_at) AS signup_month",
          "users.created_at AS user_created_at",
          "MIN(optimizations.created_at) AS first_opt_at"
        )
        .left_joins(projects: :optimizations)
        .group("users.id, signup_month, users.created_at")
        .order("signup_month ASC")

      # Group rows by cohort month, then compute retention for each threshold
      cohorts_raw = retention_rows.group_by { |r| r.signup_month.to_date.beginning_of_month }

      @retention_cohorts = cohorts_raw.map do |month_date, rows|
        total = rows.size
        cohort_age_days = (today - month_date.to_date).to_i

        build_retention = lambda do |days|
          next nil if cohort_age_days < days

          count = rows.count do |r|
            r.first_opt_at.present? &&
              r.first_opt_at.to_time > r.user_created_at.to_time + days.days
          end
          pct = total.zero? ? 0.0 : (count.to_f / total * 100).round(1)
          { count: count, pct: pct }
        end

        {
          month:     month_date.strftime("%b %Y"),
          total:     total,
          return_7:  build_retention.call(7),
          return_14: build_retention.call(14),
          return_30: build_retention.call(30)
        }
      end
    end
  end
end
