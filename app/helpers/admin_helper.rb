module AdminHelper
  def admin_nav_link(label, path, controller_name)
    current = params[:controller]
    active = current == "admin/#{controller_name}" ||
             (controller_name == "dashboard" && current == "admin/dashboard") ||
             (controller_name == "projects" && current == "admin/optimizations")
    classes = if active
      "flex items-center px-3 py-2 text-sm font-medium rounded-md bg-gray-100 text-gray-900"
    else
      "flex items-center px-3 py-2 text-sm font-medium rounded-md text-gray-600 hover:bg-gray-50 hover:text-gray-900"
    end
    link_to label, path, class: classes
  end

  def admin_pagination
    return if @total_pages <= 1

    content_tag(:nav, class: "flex items-center justify-between border-t border-gray-200 pt-4 mt-6") do
      info = content_tag(:span, "Page #{@current_page} of #{@total_pages} (#{@total_count} total)", class: "text-sm text-gray-500")

      links = content_tag(:div, class: "flex gap-2") do
        prev_link = if @current_page > 1
          link_to "Previous", url_for(page: @current_page - 1), class: "px-3 py-1.5 text-sm border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        else
          content_tag(:span, "Previous", class: "px-3 py-1.5 text-sm border border-gray-200 rounded-md text-gray-400")
        end

        next_link = if @current_page < @total_pages
          link_to "Next", url_for(page: @current_page + 1), class: "px-3 py-1.5 text-sm border border-gray-300 rounded-md text-gray-700 hover:bg-gray-50"
        else
          content_tag(:span, "Next", class: "px-3 py-1.5 text-sm border border-gray-200 rounded-md text-gray-400")
        end

        safe_join([ prev_link, next_link ])
      end

      safe_join([ info, links ])
    end
  end
end
