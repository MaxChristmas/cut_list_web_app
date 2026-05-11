class Feedback < ApplicationRecord
  belongs_to :user

  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :user_id, uniqueness: { message: :already_submitted }

  scope :treated, -> { where.not(treated_at: nil) }
  scope :untreated, -> { where(treated_at: nil) }

  def complete?
    rating.present? && improvement.present? && feature_request.present?
  end

  def treated?
    treated_at.present?
  end
end
