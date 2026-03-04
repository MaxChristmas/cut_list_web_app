class Optimization < ApplicationRecord
  belongs_to :project, counter_cache: true

  validates :cut_direction, inclusion: { in: %w[auto along_length along_width] }
end
