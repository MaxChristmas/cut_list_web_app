class Project < ApplicationRecord
  belongs_to :user, optional: true
  has_many :optimizations, dependent: :destroy

  before_create :generate_token

  validates :token, uniqueness: true
  validates :grain_direction, inclusion: { in: %w[none along_length along_width] }
  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :templates, -> { where(template: true) }

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  private

  def generate_token
    self.token = SecureRandom.alphanumeric(20)
  end
end
