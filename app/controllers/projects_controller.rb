class ProjectsController < ApplicationController
  RATE_LIMIT_STORE = ActiveSupport::Cache::MemoryStore.new
  rate_limit to: 3, within: 1.second, only: [:create, :update],
             store: RATE_LIMIT_STORE, with: -> { head :too_many_requests }

  before_action :reject_template_project, only: [:update, :save_layout, :reset_layout, :archive, :unarchive]
  before_action :require_archive_feature!, only: [:archive, :unarchive]

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

    pdf = CutListPdfService.new(result, @project, colors: params[:colors] != "0").generate
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
    @grain_direction = @project.grain_direction || "none"
    @original_result = @optimization&.result
    @edited_result = @optimization&.edited_result
    @result = @edited_result || @original_result
    @pieces = @original_result&.dig("pieces") || []
  end

  def create
    unless user_signed_in?
      redirect_to root_path, flash: { show_signup: t("limits.guest_signup_prompt") }
      return
    end

    unless can_create_project?
      redirect_to plans_path, alert: t("limits.max_projects_reached")
      return
    end

    stock_l = params[:stock_l]
    stock_w = params[:stock_w]
    kerf = params[:kerf] || 0
    cut_direction = params[:cut_direction] || "auto"
    grain_direction = params[:grain_direction] || "none"
    pieces = parse_pieces

    stock = { l: stock_l, w: stock_w }
    cuts = build_cuts(pieces, grain_direction: grain_direction)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf, cut_direction: cut_direction, grain_direction: grain_direction)

    @project = Project.create!(
      name: params[:name].presence,
      sheet_length: stock_l.to_i,
      sheet_width: stock_w.to_i,
      grain_direction: grain_direction,
      user: current_user
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed",
      cut_direction: cut_direction
    )

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @name = params[:name]
    @stock_l = stock_l
    @stock_w = stock_w
    @kerf = kerf
    @cut_direction = cut_direction
    @grain_direction = grain_direction
    @pieces = pieces || []
    render :index, status: :unprocessable_entity
  end

  def update
    @project = Project.find_by!(token: params[:token])

    unless user_signed_in?
      redirect_to project_path(@project.token), flash: { show_signup: t("limits.guest_signup_prompt") }
      return
    end

    unless can_run_optimization?(@project)
      redirect_to plans_path, alert: t("limits.daily_optimizations_reached")
      return
    end

    stock_l = params[:stock_l]
    stock_w = params[:stock_w]
    kerf = params[:kerf] || 0
    cut_direction = params[:cut_direction] || "auto"
    grain_direction = params[:grain_direction] || "none"
    pieces = parse_pieces

    stock = { l: stock_l, w: stock_w }
    cuts = build_cuts(pieces, grain_direction: grain_direction)

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf, cut_direction: cut_direction, grain_direction: grain_direction)

    @project.update!(
      name: params[:name].presence,
      sheet_length: stock_l.to_i,
      sheet_width: stock_w.to_i,
      grain_direction: grain_direction
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed",
      cut_direction: cut_direction
    )

    redirect_to project_path(@project.token)
  rescue => e
    @error = e.message
    @name = params[:name]
    @stock_l = stock_l
    @stock_w = stock_w
    @kerf = kerf
    @cut_direction = cut_direction
    @grain_direction = grain_direction
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
      if user_signed_in?
        redirect_to project_path(@project.token), alert: t("projects.unarchive_limit_reached")
      else
        redirect_to project_path(@project.token), flash: { show_signup: t("limits.guest_signup_prompt") }
      end
      return
    end

    @project.unarchive!
    redirect_to project_path(@project.token), notice: t("projects.unarchived")
  end

  private

  def require_archive_feature!
    unless has_feature?(:archive)
      project = Project.find_by!(token: params[:token])
      redirect_to project_path(project.token), alert: t("limits.feature_not_available")
    end
  end

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
      h[:grain] = piece[:grain] if piece[:grain].present? && piece[:grain] != "auto"
      h
    end
  end

  def build_cuts(pieces, grain_direction:)
    pieces.map do |piece|
      cut = {
        l: piece[:length],
        w: piece[:width],
        qty: piece[:quantity]
      }
      cut[:grain] = grain_direction == "none" ? "auto" : (piece[:grain] || "auto")
      cut
    end
  end
end
