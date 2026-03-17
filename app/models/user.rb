class User < ApplicationRecord
  include Plannable
  include Scorable

  # Include default devise modules. Others available are:
  # :confirmable, :timeoutable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :lockable, :trackable,
         :omniauthable, omniauth_providers: [ :google_oauth2 ]

  has_many :projects, dependent: :nullify
  has_many :coupon_redemptions, dependent: :destroy
  has_many :scan_tokens, dependent: :delete_all

  scope :kept, -> { where(discarded_at: nil) }
  scope :discarded, -> { where.not(discarded_at: nil) }
  scope :public_users, -> { where(internal: false) }

  def discarded?
    discarded_at.present?
  end

  def soft_delete!
    update!(
      discarded_at: Time.current,
      email: "deleted-#{id}@anonymized.local",
      provider: nil,
      uid: nil,
      stripe_customer_id: nil,
      stripe_subscription_id: nil,
      locked_at: Time.current,
      sign_in_count: 0,
      current_sign_in_at: nil,
      last_sign_in_at: nil,
      current_sign_in_ip: nil,
      last_sign_in_ip: nil,
      last_sign_in_city: nil,
      last_sign_in_country: nil,
      last_sign_in_device: nil
    )
  end

  validates :locale, inclusion: { in: I18n.available_locales.map(&:to_s) }, allow_nil: true

  attribute :terms_accepted, :boolean
  validates :terms_accepted, acceptance: true, on: :create

  before_create :set_terms_accepted_at, if: :terms_accepted

  def self.from_omniauth(auth)
    user = find_by(provider: auth.provider, uid: auth.uid)
    return user if user

    user = find_by(email: auth.info.email)
    if user
      user.update!(provider: auth.provider, uid: auth.uid)
      return user
    end

    create!(
      email: auth.info.email,
      password: Devise.friendly_token(32),
      provider: auth.provider,
      uid: auth.uid,
      terms_accepted: true
    )
  end

  def password_required?
    super && provider.blank?
  end

  private

  def set_terms_accepted_at
    self.terms_accepted_at = Time.current
  end
end
