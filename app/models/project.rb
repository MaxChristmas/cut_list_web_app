class Project < ApplicationRecord
  belongs_to :user, optional: true
  has_many :optimizations, dependent: :destroy

  before_create :generate_token

  validates :token, uniqueness: true

  private

  def generate_token
    self.token = SecureRandom.alphanumeric(20)
  end
end
