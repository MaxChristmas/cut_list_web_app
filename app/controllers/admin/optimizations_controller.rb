module Admin
  class OptimizationsController < BaseController
    def index
      @optimizations = paginate(Optimization.includes(project: :user).order(created_at: :desc))
    end

    def show
      @optimization = Optimization.find(params[:id])
    end
  end
end
