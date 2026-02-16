module Admin
  class OptimizationsController < BaseController
    before_action :set_project

    def index
      @optimizations = paginate(@project.optimizations.order(created_at: :desc))
    end

    def show
      @optimization = @project.optimizations.find(params[:id])
    end

    private

    def set_project
      @project = Project.find(params[:project_id])
    end
  end
end
