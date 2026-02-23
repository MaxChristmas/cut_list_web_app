class User < ApplicationRecord
  include Plannable

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable,
         :omniauthable, omniauth_providers: [:google_oauth2]

  has_many :projects, dependent: :nullify

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
