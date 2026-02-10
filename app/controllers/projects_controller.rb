class ProjectsController < ApplicationController
  def index
  end

  def show
  end

  def new
  end

  def create
    @stock_w = params[:stock_w]
    @stock_h = params[:stock_h]
    @kerf = params[:kerf] || 0
    @pieces = (params[:pieces] || []).map do |piece|
      { length: piece[:length], height: piece[:height], quantity: piece[:quantity], allow_rotate: piece[:allow_rotate] }
    end

    stock = { w: @stock_w, h: @stock_h }
    cuts = @pieces.filter_map do |piece|
      next if piece[:length].blank? || piece[:height].blank?

      {
        w: piece[:length],
        h: piece[:height],
        qty: piece[:quantity],
        allow_rotate: piece[:allow_rotate] == "1"
      }
    end

    @result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: @kerf)
    render :index
  rescue => e
    @error = e.message
    render :index
  end

  def edit
  end

  def update
  end
end
