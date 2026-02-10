class ProjectsController < ApplicationController
  def index
  end

  def export_pdf
    @project = Project.find_by!(token: params[:token])
    optimization = @project.optimizations.order(created_at: :desc).first
    result = optimization&.result

    if result.blank?
      redirect_to project_path(@project.token), alert: "No optimization results to export."
      return
    end

    pdf = CutListPdfService.new(result, @project).generate
    send_data pdf.render, filename: "cut-list-#{@project.token}.pdf",
              type: "application/pdf", disposition: "attachment"
  end

  def show
    @project = Project.find_by!(token: params[:token])
    @optimization = @project.optimizations.order(created_at: :desc).first

    @stock_w = @project.sheet_width
    @stock_h = @project.sheet_height
    @kerf = @optimization&.result&.dig("kerf") || 0
    @result = @optimization&.result
    @pieces = @optimization&.result&.dig("pieces") || []
  end

  def create
    unless can_create_project?
      redirect_to root_path, alert: t("limits.max_projects_reached")
      return
    end

    unless can_run_optimization?
      redirect_to root_path, alert: t("limits.daily_optimizations_reached")
      return
    end

    stock_w = params[:stock_w]
    stock_h = params[:stock_h]
    kerf = params[:kerf] || 0
    pieces = parse_pieces

    stock = { w: stock_w, h: stock_h }
    cuts = build_cuts(pieces)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf)

    @project = Project.create!(
      sheet_width: stock_w.to_i,
      sheet_height: stock_h.to_i,
      user: current_user
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed"
    )

    if user_signed_in?
      # Project already associated via current_user
    else
      GuestLimits.track_project!(session, @project.token)
      GuestLimits.record_optimization!(session)
    end

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @stock_w = stock_w
    @stock_h = stock_h
    @kerf = kerf
    @pieces = pieces || []
    render :index, status: :unprocessable_entity
  end

  def update
    @project = Project.find_by!(token: params[:token])

    unless can_run_optimization?
      redirect_to project_path(@project.token), alert: t("limits.daily_optimizations_reached")
      return
    end

    stock_w = params[:stock_w]
    stock_h = params[:stock_h]
    kerf = params[:kerf] || 0
    pieces = parse_pieces

    stock = { w: stock_w, h: stock_h }
    cuts = build_cuts(pieces)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf)

    @project.update!(
      sheet_width: stock_w.to_i,
      sheet_height: stock_h.to_i
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed"
    )

    GuestLimits.record_optimization!(session) unless user_signed_in?

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @stock_w = stock_w
    @stock_h = stock_h
    @kerf = kerf
    @pieces = pieces || []
    @result = @project&.optimizations&.order(created_at: :desc)&.first&.result
    render :show, status: :unprocessable_entity
  end

  def archive
    @project = Project.find_by!(token: params[:token])
    @project.archive!
    redirect_to root_path, notice: t("projects.archived")
  end

  def unarchive
    @project = Project.find_by!(token: params[:token])

    unless can_create_project?
      redirect_to project_path(@project.token), alert: t("projects.unarchive_limit_reached")
      return
    end

    @project.unarchive!
    redirect_to project_path(@project.token), notice: t("projects.unarchived")
  end

  private

  def parse_pieces
    (params[:pieces] || []).filter_map do |piece|
      next if piece[:length].blank? || piece[:height].blank?
      { length: piece[:length], height: piece[:height], quantity: piece[:quantity], allow_rotate: piece[:allow_rotate] }
    end
  end

  def build_cuts(pieces)
    pieces.map do |piece|
      {
        w: piece[:length],
        h: piece[:height],
        qty: piece[:quantity],
        allow_rotate: piece[:allow_rotate] == "1"
      }
    end
  end
end
