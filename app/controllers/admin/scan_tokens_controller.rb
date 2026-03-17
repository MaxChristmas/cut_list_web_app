module Admin
  class ScanTokensController < BaseController
    def index
      scope = ScanToken.includes(:user).order(created_at: :desc)
      scope = scope.where(status: params[:status]) if params[:status].present?
      scope = scope.where(image_type: params[:agent]) if params[:agent].present?
      @scan_tokens = paginate(scope)

      # Stats (always computed on all scan_tokens, not filtered)
      all = ScanToken.all
      @stats = {
        total: all.count,
        completed: all.where(status: "completed").count,
        total_cost: all.sum(:cost_usd) || 0,
        agent_counts: all.where.not(image_type: nil).group(:image_type).count
      }
    end

    def show
      @scan_token = ScanToken.find(params[:id])
    end
  end
end
