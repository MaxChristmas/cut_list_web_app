module Admin
  class FeedbacksController < BaseController
    def index
      scope = Feedback.includes(:user).order(created_at: :desc)
      @average_rating = Feedback.average(:rating)&.round(1)
      @feedbacks = paginate(scope)
    end

    def show
      @feedback = Feedback.includes(:user).find(params[:id])
      if @feedback.read_at.nil?
        @feedback.update(read_at: Time.current)
        @unread_feedbacks_count = Feedback.unread.count
      end
    end

    def destroy
      Feedback.find(params[:id]).destroy
      redirect_to admin_feedbacks_path, notice: "Feedback deleted."
    end
  end
end
