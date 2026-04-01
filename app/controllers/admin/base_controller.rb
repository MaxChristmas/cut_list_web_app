module Admin
  class BaseController < ActionController::Base
    before_action :authenticate_admin_user!
    before_action :set_unread_feedbacks_count
    layout "admin"

    private

    PER_PAGE = 25

    def set_unread_feedbacks_count
      @unread_feedbacks_count = Feedback.unread.count
    end

    def paginate(scope)
      page = [ params[:page].to_i, 1 ].max
      total = scope.count
      @total_count = total.is_a?(Hash) ? total.size : total
      @current_page = page
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @total_pages = 1 if @total_pages < 1
      scope.offset((page - 1) * PER_PAGE).limit(PER_PAGE)
    end

    def paginate_array(array)
      page = [ params[:page].to_i, 1 ].max
      @total_count = array.size
      @current_page = page
      @total_pages = (@total_count.to_f / PER_PAGE).ceil
      @total_pages = 1 if @total_pages < 1
      array.slice((page - 1) * PER_PAGE, PER_PAGE) || []
    end
  end
end
