class Users::SessionsController < Devise::SessionsController
  def create
    super do |user|
      claim_guest_projects(user)
    end
  end
end
