class BrevoTrackEventJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(email:, event_name:, properties: {})
    BrevoService.track_event(email: email, event_name: event_name, properties: properties)
  end
end
