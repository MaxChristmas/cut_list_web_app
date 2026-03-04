class NtfyOptimizationJob < ApplicationJob
  discard_on StandardError

  def perform(user, optimization)
    location = [ user.last_sign_in_city, user.last_sign_in_country ].compact.join(", ")
    location = "Unknown" if location.blank?

    NtfyJob.perform_later(
      title: "New optimization",
      tags: "scissors",
      message: [
        "Email: #{user.email}",
        "Time: #{optimization.created_at.strftime('%b %d, %Y at %H:%M UTC')}",
        "Location: #{location}",
        "Sheets: #{optimization.sheets_count} | Efficiency: #{optimization.efficiency&.round(1)}%"
      ].join("\n")
    )
  end
end
