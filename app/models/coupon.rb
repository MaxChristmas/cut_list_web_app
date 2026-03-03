class Coupon < ApplicationRecord
  has_many :coupon_redemptions, dependent: :destroy
  has_many :users, through: :coupon_redemptions

  validates :code, presence: true, uniqueness: true, format: { with: /\A[0-9A-Z]{6}\z/ }
  validates :plan, presence: true, inclusion: { in: %w[worker enterprise] }
  validates :duration_days, presence: true, numericality: { greater_than: 0 }
  validates :max_uses, numericality: { greater_than: 0 }, allow_nil: true
  validate :code_immutable_after_use, on: :update

  before_validation :generate_code, on: :create
  before_validation :normalize_code

  scope :active, -> {
    where("expires_at IS NULL OR expires_at > ?", Time.current)
      .where("max_uses IS NULL OR uses_count < max_uses")
  }

  def redeemable?
    (expires_at.nil? || expires_at > Time.current) &&
      (max_uses.nil? || uses_count < max_uses)
  end

  def expired?
    expires_at.present? && expires_at <= Time.current
  end

  def redeem!(user)
    transaction do
      coupon_redemptions.create!(user: user)
      increment!(:uses_count)
      user.update!(plan: plan, plan_expires_at: duration_days.days.from_now)
    end
  end

  private

  def generate_code
    return if code.present?

    self.code = loop do
      candidate = SecureRandom.hex(3).upcase
      break candidate unless Coupon.exists?(code: candidate)
    end
  end

  def normalize_code
    self.code = code.upcase.strip if code.present?
  end

  def code_immutable_after_use
    if code_changed? && uses_count > 0
      errors.add(:code, "cannot be changed after the coupon has been used")
    end
  end
end
