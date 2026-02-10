class PlansController < ApplicationController
  def index
    @plans = Plannable::PLANS
    @current_plan = user_signed_in? ? current_user.plan : "free"
  end

  def update
    authenticate_user!
    plan = params[:plan]

    if Plannable::PLANS.key?(plan)
      current_user.update!(plan: plan)
      redirect_to plans_path, notice: t("plans.updated", plan: t("plans.#{plan}.name"))
    else
      redirect_to plans_path, alert: t("plans.invalid")
    end
  end
end
