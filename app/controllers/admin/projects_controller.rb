module Admin
  class ProjectsController < BaseController
    def index
      @projects = paginate(Project.includes(:user, :pdf_exports).order(created_at: :desc))
    end

    def show
      @project = Project.find(params[:id])
      @optimizations = @project.optimizations.order(created_at: :desc)
    end
  end
end
