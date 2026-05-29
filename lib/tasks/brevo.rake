namespace :brevo do
  desc "Sync all active users to Brevo (safe to re-run — uses upsert)"
  task sync_all_users: :environment do
    scope = User.kept.public_users
    total = scope.count
    puts "Enqueueing Brevo sync for #{total} users..."

    scope.find_each.with_index(1) do |user, i|
      BrevoSyncContactJob.perform_later(user)
      print "." if (i % 50).zero?
    end

    puts "\nDone. #{total} jobs enqueued."
  end
end
