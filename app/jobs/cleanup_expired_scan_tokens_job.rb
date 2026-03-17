class CleanupExpiredScanTokensJob < ApplicationJob
  queue_as :default

  def perform
    ScanToken.where("expires_at < ?", 1.hour.ago).delete_all
  end
end
