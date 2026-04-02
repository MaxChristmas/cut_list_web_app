class BrevoSyncContactJob < ApplicationJob
  queue_as :default
  discard_on StandardError

  def perform(user)
    BrevoService.sync_contact(user)
  end
end
