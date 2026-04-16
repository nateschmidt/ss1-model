class Entity < ApplicationRecord
  TYPES = %w[consortium investor operator third_party].freeze

  validates :name, presence: true
  validates :entity_type, inclusion: { in: TYPES }

  scope :ordered, -> { order(:position) }

  def consortium?
    entity_type == "consortium"
  end

  def investor?
    entity_type == "investor"
  end

  def operator?
    entity_type == "operator"
  end

  def third_party?
    entity_type == "third_party"
  end
end
