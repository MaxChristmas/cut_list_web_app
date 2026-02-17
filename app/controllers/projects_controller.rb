class ProjectsController < ApplicationController
  before_action :reject_template_project, only: [:update, :save_layout, :reset_layout, :archive, :unarchive]

  def index
  end

  def export_pdf
    @project = Project.find_by!(token: params[:token])
    optimization = @project.optimizations.order(created_at: :desc).first
    result = optimization&.edited_result || optimization&.result

    if result.blank?
      redirect_to project_path(@project.token), alert: "No optimization results to export."
      return
    end

    pdf = CutListPdfService.new(result, @project).generate
    filename = if @project.name.present?
      "#{@project.name.parameterize}.pdf"
    else
      "cut-list-#{@project.token}.pdf"
    end
    send_data pdf.render, filename: filename,
              type: "application/pdf", disposition: "attachment"
  end

  def export_labels
    @project = Project.find_by!(token: params[:token])

    # Collect all project tokens (current + extras)
    tokens = [params[:token]]
    tokens.concat(Array(params[:tokens])) if params[:tokens].present?
    tokens.uniq!

    projects = Project.where(token: tokens)
    entries = projects.filter_map do |project|
      optimization = project.optimizations.order(created_at: :desc).first
      result = optimization&.result
      next if result.blank?
      { result: result, project_name: project.name.presence || "#{project.sheet_length}×#{project.sheet_width}" }
    end

    if entries.empty?
      redirect_to project_path(@project.token), alert: "No optimization results to export."
      return
    end

    label_format = params[:label_format] || "24"
    pdf = LabelPdfService.new(entries, label_format).generate
    filename = if projects.size == 1 && @project.name.present?
      "#{@project.name.parameterize}-labels.pdf"
    else
      "labels-#{@project.token}.pdf"
    end
    send_data pdf.render, filename: filename,
              type: "application/pdf", disposition: "attachment"
  end

  def show
    @project = Project.find_by!(token: params[:token])
    @optimization = @project.optimizations.order(created_at: :desc).first

    @name = @project.name
    @stock_l = @project.sheet_length
    @stock_w = @project.sheet_width
    @kerf = @optimization&.result&.dig("kerf") || 0
    @cut_direction = @optimization&.cut_direction || "auto"
    @allow_rotation = @project.allow_rotation.nil? ? true : @project.allow_rotation
    @original_result = @optimization&.result
    @edited_result = @optimization&.edited_result
    @result = @edited_result || @original_result
    @pieces = @original_result&.dig("pieces") || []
  end

  def create
    unless can_create_project?
      redirect_to root_path, alert: t("limits.max_projects_reached")
      return
    end

    stock_l = params[:stock_l]
    stock_w = params[:stock_w]
    kerf = params[:kerf] || 0
    cut_direction = params[:cut_direction] || "auto"
    allow_rotation = params[:allow_rotation] == "1"
    pieces = parse_pieces

    stock = { l: stock_l, w: stock_w }
    cuts = build_cuts(pieces)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf, cut_direction: cut_direction, allow_rotate: allow_rotation)

    @project = Project.create!(
      name: params[:name].presence,
      sheet_length: stock_l.to_i,
      sheet_width: stock_w.to_i,
      allow_rotation: allow_rotation,
      user: current_user
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed",
      cut_direction: cut_direction
    )

    if user_signed_in?
      # Project already associated via current_user
    else
      GuestLimits.track_project!(session, @project.token)
      GuestLimits.record_optimization!(session, @project.token)
    end

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @name = params[:name]
    @stock_l = stock_l
    @stock_w = stock_w
    @kerf = kerf
    @cut_direction = cut_direction
    @allow_rotation = allow_rotation
    @pieces = pieces || []
    render :index, status: :unprocessable_entity
  end

  def update
    @project = Project.find_by!(token: params[:token])

    unless can_run_optimization?(@project)
      redirect_to project_path(@project.token), alert: t("limits.monthly_optimizations_reached")
      return
    end

    stock_l = params[:stock_l]
    stock_w = params[:stock_w]
    kerf = params[:kerf] || 0
    cut_direction = params[:cut_direction] || "auto"
    allow_rotation = params[:allow_rotation] == "1"
    pieces = parse_pieces

    stock = { l: stock_l, w: stock_w }
    cuts = build_cuts(pieces)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf, cut_direction: cut_direction, allow_rotate: allow_rotation)

    @project.update!(
      name: params[:name].presence,
      sheet_length: stock_l.to_i,
      sheet_width: stock_w.to_i,
      allow_rotation: allow_rotation
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed",
      cut_direction: cut_direction
    )

    GuestLimits.record_optimization!(session, @project.token) unless user_signed_in?

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @name = params[:name]
    @stock_l = stock_l
    @stock_w = stock_w
    @kerf = kerf
    @cut_direction = cut_direction
    @allow_rotation = allow_rotation
    @pieces = pieces || []
    @result = @project&.optimizations&.order(created_at: :desc)&.first&.result
    render :show, status: :unprocessable_entity
  end

  def save_layout
    @project = Project.find_by!(token: params[:token])
    optimization = @project.optimizations.order(created_at: :desc).first

    if optimization
      edited_result = JSON.parse(request.body.read)
      optimization.update!(edited_result: edited_result)
      head :ok
    else
      head :not_found
    end
  end

  def reset_layout
    @project = Project.find_by!(token: params[:token])
    optimization = @project.optimizations.order(created_at: :desc).first

    if optimization
      optimization.update!(edited_result: nil)
      redirect_to project_path(@project.token)
    else
      head :not_found
    end
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

  def reject_template_project
    project = Project.find_by!(token: params[:token])
    if project.template?
      redirect_to project_path(project.token), alert: t("projects.template_read_only")
    end
  end

  def parse_pieces
    (params[:pieces] || []).filter_map do |piece|
      next if piece[:length].blank? || piece[:width].blank?
      h = { length: piece[:length], width: piece[:width], quantity: piece[:quantity] }
      h[:label] = piece[:label].strip if piece[:label].present?
      h
    end
  end

  def build_cuts(pieces)
    pieces.map do |piece|
      {
        l: piece[:length],
        w: piece[:width],
        qty: piece[:quantity]
      }
    end
  end
end
