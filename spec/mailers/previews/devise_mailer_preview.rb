class DeviseMailerPreview < ActionMailer::Preview
  def reset_password_instructions
    user = User.first || User.new(email: "preview@example.com")
    Devise::Mailer.reset_password_instructions(user, "fake-token-for-preview")
  end
end
