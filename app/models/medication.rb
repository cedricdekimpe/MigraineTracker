class Medication < ApplicationRecord
  # What the medication is, which decides how its days are counted for the overuse thresholds:
  # acute       simple analgesic or NSAID (X on the paper calendar), ICHD-3 limit 15 days a month
  # combination combined analgesic (caffeine, codeine...) or opioid (X), limit 10 days
  # triptan     (t), limit 10 days
  # gepant      gepant or ditan (X), no limit of its own but counted in the mixed total
  # preventive  daily treatment, tracked in treatment periods rather than as intakes
  # other       anything else, e.g. an anti-nausea drug: never counted
  KINDS = %w[acute combination triptan gepant preventive other].freeze
  COUNTED_KINDS = %w[acute combination triptan gepant].freeze
  SUGGESTED_KINDS = %w[acute combination triptan gepant other preventive].freeze

  belongs_to :user
  has_many :medication_intakes, dependent: :restrict_with_error
  has_many :episodes, through: :medication_intakes
  has_many :treatment_periods, dependent: :destroy

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

  # { "triptan" => ["Sumatriptan", ...], ... } in the current locale
  def self.suggestions
    SUGGESTED_KINDS.index_with { |kind| I18n.t("medication_suggestions.#{kind}") }
  end

  # Class of a suggested name (matching a suggestion ignoring case), nil for a name we do not know:
  # guessing would silently move days in or out of the overuse counts, so the person is asked.
  def self.kind_for(name)
    clean = name.to_s.strip.downcase
    suggestions.each { |kind, names| return kind if names.any? { |suggestion| suggestion.downcase == clean } }
    nil
  end

  # Whether intakes of this medication count as a treatment day (X or t on the calendar).
  def counted?
    kind.in?(COUNTED_KINDS)
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

  # Archives a medication that has history (intakes or treatment periods), deletes one that was never used.
  def retire!
    medication_intakes.exists? || treatment_periods.exists? ? archive! : destroy!
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
