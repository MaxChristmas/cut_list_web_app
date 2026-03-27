class Feedback < ApplicationRecord
  belongs_to :user

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { message: :already_submitted }
end
