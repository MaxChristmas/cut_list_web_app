class FeedbacksController < ApplicationController
  before_action :authenticate_user!

  def create
    @feedback = current_user.feedbacks.build(feedback_params)

    if @feedback.save
      render json: { id: @feedback.id }, status: :created
    else
      head :unprocessable_entity
    end
  end

  def update
    @feedback = current_user.feedbacks.find(params[:id])
    if @feedback.update(feedback_params)
      head :ok
    else
      head :unprocessable_entity
    end
  end

  def dismiss
    current_user.update!(feedback_dismissed_at: Time.current)
    head :ok
  end

  private

  def feedback_params
    params.require(:feedback).permit(:rating, :improvement, :feature_request)
  end
end
