class ReportIssue < ApplicationRecord
  belongs_to :user
  belongs_to :replied_by, class_name: "AdminUser", optional: true

  validates :body, presence: true

  def replied?
    reply_body.present?
  end
end
