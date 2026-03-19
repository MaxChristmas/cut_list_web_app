class ScanTokensController < ApplicationController
  before_action :authenticate_user!

  def create
    unless has_feature?(:photo_import)
      head :forbidden
      return
    end

    unless current_user.can_scan?
      render html: error_html(t("scan.monthly_limit_reached")), status: :unprocessable_entity
      return
    end

    project = current_user.projects.find_by(token: params[:project_token]) if params[:project_token].present?

    # Expire any previous pending tokens for this user
    current_user.scan_tokens.valid_pending.update_all(status: "expired")

    @scan_token = current_user.scan_tokens.create!(project: project, ai_provider: "anthropic")

    render partial: "scan_tokens/qr_code", locals: { scan_token: @scan_token }, layout: false
  end

  def submit_pieces
    scan_token = current_user.scan_tokens.find(params[:id])
    scan_token.update!(submitted_pieces: params[:pieces])
    head :ok
  end

  private

  def error_html(message)
    <<~HTML.html_safe
      <p class="text-red-400 text-sm text-center py-4">#{ERB::Util.html_escape(message)}</p>
    HTML
  end
end
