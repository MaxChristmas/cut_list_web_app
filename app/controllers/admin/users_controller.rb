module Admin
  class UsersController < BaseController
    before_action :set_user, only: [ :show, :edit, :update, :destroy, :soft_delete ]

    SCORE_RANGES = [
      [ "all", "All scores", 0..100 ],
      [ "0-10", "0 - 10", 0..10 ],
      [ "10-20", "10 - 20", 11..20 ],
      [ "20-30", "20 - 30", 21..30 ],
      [ "30-50", "30 - 50", 31..50 ],
      [ "50-70", "50 - 70", 51..70 ],
      [ "70-100", "70 - 100", 71..100 ]
    ].freeze

    SORT_OPTIONS = %w[created_at projects_count].freeze

    def index
      @score_filter = params[:score] || "all"
      @plan_filter = params[:plan] || "all"
      @sort = SORT_OPTIONS.include?(params[:sort]) ? params[:sort] : "created_at"
      @sort_direction = params[:direction] == "asc" ? "asc" : "desc"

      scope = User.all
      scope = scope.where(plan: @plan_filter) if @plan_filter != "all"

      scope = apply_sort(scope)

      score_range = SCORE_RANGES.find { |key, _, _| key == @score_filter }&.last

      if score_range && @score_filter != "all"
        users = scope.includes(:projects, :coupon_redemptions)
        filtered = users.select { |u| score_range.cover?(u.engagement_score) }
        @users = paginate_array(filtered)
      else
        @score_filter = "all"
        @users = paginate(scope)
      end
    end

    def show
      @projects = @user.projects.order(created_at: :desc)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(user_params)
      if @user.save
        redirect_to admin_user_path(@user), notice: "User created successfully."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
    end

    def update
      params_to_use = user_params
      params_to_use = params_to_use.except(:password, :password_confirmation) if params_to_use[:password].blank?
      if @user.update(params_to_use)
        redirect_to admin_user_path(@user), notice: "User updated successfully."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def soft_delete
      @user.soft_delete!
      redirect_to admin_user_path(@user), notice: "User has been soft deleted and anonymized."
    end

    def destroy
      @user.destroy
      redirect_to admin_users_path, notice: "User permanently deleted."
    end

    private

    def apply_sort(scope)
      if @sort == "projects_count"
        scope.left_joins(:projects)
             .group(:id)
             .order(Arel.sql("COUNT(projects.id)").send(@sort_direction.to_sym))
      else
        scope.order(created_at: @sort_direction.to_sym)
      end
    end

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.expect(user: [ :email, :password, :password_confirmation, :plan, :plan_expires_at, :internal ])
    end
  end
end
