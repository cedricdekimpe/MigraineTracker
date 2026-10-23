class Medication < ApplicationRecord
  KINDS = %w[acute preventive other].freeze

  belongs_to :user
  has_many :medication_intakes, dependent: :restrict_with_error
  has_many :episodes, through: :medication_intakes

  before_validation :normalize_fields

  validates :name, presence: true, length: { maximum: 100 }, uniqueness: { scope: :user_id, case_sensitive: false }
  validates :kind, inclusion: { in: KINDS }
  validates :default_dose, length: { maximum: 50 }

  scope :active, -> { where(archived_at: nil) }
  scope :archived, -> { where.not(archived_at: nil) }
  scope :alphabetical, -> { order(Arel.sql("lower(medications.name)")) }
  # Most used first, so the entry form can offer the usual ones as one-tap chips.
  scope :most_used_first, -> {
    left_joins(:medication_intakes).group("medications.id")
      .order(Arel.sql("COUNT(medication_intakes.id) DESC"), Arel.sql("lower(medications.name)"))
  }

  # Finds the user's medication by name (ignoring case), un-archiving it, or creates it.
  def self.find_or_create_for(user, name, **attributes)
    clean = name.to_s.strip
    medication = user.medications.find_by("lower(name) = ?", clean.downcase) || user.medications.new(name: clean, **attributes)
    medication.archived_at = nil
    medication.save
    medication
  end

  def archived?
    archived_at.present?
  end

  def archive!
    update!(archived_at: Time.current)
  end

  def unarchive!
    update!(archived_at: nil)
  end

  # Archives a medication that has history, deletes one that was never used.
  def retire!
    medication_intakes.exists? ? archive! : destroy!
  end

  def abbreviation
    name.to_s.strip.first(3).capitalize.presence || "-"
  end

  private

  def normalize_fields
    self.name = name.to_s.strip
    self.default_dose = default_dose.to_s.strip.presence
  end
end
