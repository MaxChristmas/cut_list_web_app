class ProjectsController < ApplicationController
  def index
  end

  def show
  end

  def new
  end

  def create
    stock = { w: params[:stock_w], h: params[:stock_h] }
    kerf = params[:kerf] || 0

    cuts = (params[:pieces] || []).filter_map do |piece|
      next if piece[:length].blank? || piece[:height].blank?

      {
        w: piece[:length],
        h: piece[:height],
        qty: piece[:quantity],
        allow_rotate: piece[:allow_rotate] == "1"
      }
    end

    @result = RustCuttingService.optimize(stock: stock, cuts: cuts, kerf: kerf)
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
