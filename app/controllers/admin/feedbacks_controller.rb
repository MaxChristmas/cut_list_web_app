module Admin
  class FeedbacksController < BaseController
    def index
      @status = %w[untreated treated all].include?(params[:status]) ? params[:status] : "untreated"
      scope = Feedback.includes(:user).order(created_at: :desc)
      scope = scope.public_send(@status) if @status != "all"
      @average_rating = Feedback.average(:rating)&.round(1)
      @feedbacks = paginate(scope)
    end

    def show
      @feedback = Feedback.includes(:user).find(params[:id])
    end

    def toggle_treated
      @feedback = Feedback.find(params[:id])
      @feedback.update!(treated_at: @feedback.treated? ? nil : Time.current)
      redirect_to admin_feedback_path(@feedback), notice: @feedback.treated? ? "Feedback marked as treated." : "Feedback marked as untreated."
    end

    def destroy
      Feedback.find(params[:id]).destroy
      redirect_to admin_feedbacks_path, notice: "Feedback deleted."
    end
  end
end
