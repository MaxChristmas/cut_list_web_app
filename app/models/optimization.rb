class Optimization < ApplicationRecord
  belongs_to :project, counter_cache: true
  belongs_to :scan_token, optional: true

  validates :cut_direction, inclusion: { in: %w[auto along_length along_width] }
end
