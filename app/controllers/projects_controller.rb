class ProjectsController < ApplicationController
  def index
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
    stock_w = params[:stock_w]
    stock_h = params[:stock_h]
    kerf = params[:kerf] || 0
    pieces = (params[:pieces] || []).map do |piece|
      { length: piece[:length], height: piece[:height], quantity: piece[:quantity], allow_rotate: piece[:allow_rotate] }
    end

    stock = { w: stock_w, h: stock_h }
    cuts = pieces.filter_map do |piece|
      next if piece[:length].blank? || piece[:height].blank?

      {
        w: piece[:length],
        h: piece[:height],
        qty: piece[:quantity],
        allow_rotate: piece[:allow_rotate] == "1"
      }
    end

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf)

    @project = Project.create!(
      sheet_width: stock_w.to_i,
      sheet_height: stock_h.to_i
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed"
    )

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

    stock_w = params[:stock_w]
    stock_h = params[:stock_h]
    kerf = params[:kerf] || 0
    pieces = (params[:pieces] || []).map do |piece|
      { length: piece[:length], height: piece[:height], quantity: piece[:quantity], allow_rotate: piece[:allow_rotate] }
    end

    stock = { w: stock_w, h: stock_h }
    cuts = pieces.filter_map do |piece|
      next if piece[:length].blank? || piece[:height].blank?

      {
        w: piece[:length],
        h: piece[:height],
        qty: piece[:quantity],
        allow_rotate: piece[:allow_rotate] == "1"
      }
    end

    result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf)

    @project.update!(
      sheet_width: stock_w.to_i,
      sheet_height: stock_h.to_i
    )

    @project.optimizations.create!(
      result: result.merge("pieces" => pieces, "kerf" => kerf),
      status: "completed"
    )

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
end
