class ReportIssue < ApplicationRecord
  belongs_to :user
  belongs_to :replied_by, class_name: "AdminUser", optional: true

  validates :body, presence: true

  scope :treated, -> { where.not(treated_at: nil) }
  scope :untreated, -> { where(treated_at: nil) }

  def replied?
    reply_body.present?
  end

  def treated?
    treated_at.present?
  end
end
