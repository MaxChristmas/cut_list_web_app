class ScanToken < ApplicationRecord
  belongs_to :user
  belongs_to :project, optional: true
  has_many :optimizations, dependent: :nullify
  has_one_attached :photo

  validates :token, presence: true, uniqueness: true
  validates :status, presence: true, inclusion: { in: %w[pending processing completed expired] }
  validates :expires_at, presence: true

  before_validation :generate_token, on: :create
  before_validation :set_expiry, on: :create

  scope :valid_pending, -> { where(status: "pending").where("expires_at > ?", Time.current) }

  def expired?
    expires_at < Time.current
  end

  def usable?
    status == "pending" && !expired?
  end

  def mark_processing!
    update!(status: "processing")
  end

  def mark_completed!(pieces)
    update!(status: "completed", result: pieces)
  end

  def pieces_modified?
    return false unless result.present? && submitted_pieces.present?

    normalize_pieces(result) != normalize_pieces(submitted_pieces)
  end

  # Returns a detailed accuracy report comparing AI output vs user submission
  def accuracy_report
    return nil unless result.present? && submitted_pieces.present?

    ai = normalize_pieces(result)
    user = normalize_pieces(submitted_pieces)

    # Match user pieces to closest AI pieces
    matched = []
    remaining_ai = ai.dup
    remaining_user = user.dup

    # First pass: match each user piece to the closest AI piece
    remaining_user.dup.each do |up|
      best_idx = nil
      best_score = Float::INFINITY

      remaining_ai.each_with_index do |ap, idx|
        score = (ap[:l] - up[:l]).abs + (ap[:w] - up[:w]).abs + ((ap[:q] - up[:q]) * 100).abs
        if score < best_score
          best_score = score
          best_idx = idx
        end
      end

      if best_idx && best_score < 10_000
        matched << { ai: remaining_ai[best_idx], user: up, diff_score: best_score }
        remaining_ai.delete_at(best_idx)
        remaining_user.delete(up)
      end
    end

    # remaining_ai = AI pieces not matched → removed by user
    # remaining_user = user pieces not matched → added by user

    # Calculate accuracy
    correct_fields = matched.count { |m| m[:ai][:l] == m[:user][:l] && m[:ai][:w] == m[:user][:w] && m[:ai][:q] == m[:user][:q] }
    total = matched.size + remaining_ai.size + remaining_user.size
    piece_accuracy = total > 0 ? (correct_fields.to_f / total * 100).round(1) : 100.0

    exact = matched.count { |m| m[:diff_score] == 0 }
    close = matched.count { |m| m[:diff_score] > 0 && m[:diff_score] <= 10 }
    wrong = matched.count { |m| m[:diff_score] > 10 }

    {
      ai_count: ai.size,
      user_count: user.size,
      matched: matched,
      added_by_user: remaining_user,
      removed_by_user: remaining_ai,
      exact_matches: exact,
      close_matches: close,
      wrong: wrong,
      accuracy_pct: piece_accuracy
    }
  end

  private

  def generate_token
    self.token ||= SecureRandom.urlsafe_base64(32)
  end

  def set_expiry
    self.expires_at ||= 10.minutes.from_now
  end

  def normalize_pieces(pieces)
    raw = pieces.is_a?(Array) ? pieces : []
    raw.map { |p|
      {
        l: (p["longueur"] || p["length"]).to_f,
        w: (p["largeur"] || p["width"]).to_f,
        q: (p["quantite"] || p["quantity"]).to_i,
        label: (p["nom"] || p["label"]).to_s
      }
    }.sort_by { |p| [ p[:l], p[:w], p[:label] ] }
  end
end
