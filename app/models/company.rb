class Company < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # The gov.uk CSV sometimes contains the literal string "NULL" for empty
  # location fields. Sanitised on assignment.
  NULL_SENTINEL = "NULL"

  # Associations
  has_many :sponsor_licences, dependent: :destroy
  has_many :sponsor_change_events, -> { order(occurred_at: :desc) }, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :name_normalised, presence: true
  validates :slug, presence: true, uniqueness: true

  # Callbacks
  before_validation :normalise_name

  # Sanitise location fields on write
  def town=(value)
    super(sanitise_location(value))
  end

  def county=(value)
    super(sanitise_location(value))
  end

  # -----------------------------------------------------------------------
  # Scopes
  # -----------------------------------------------------------------------

  # Fuzzy trigram search on the normalised name.
  # Returns companies ordered by similarity score descending.
  # Minimum similarity threshold of 0.15 keeps low-quality matches out.
  scope :fuzzy_search, ->(query) {
    normalised_query = query.to_s.strip.downcase.gsub(/\s+/, " ")
    return none if normalised_query.blank?

    where(
      "similarity(name_normalised, :q) > 0.15 OR name_normalised ILIKE :partial",
      q: normalised_query,
      partial: "%#{sanitize_sql_like(normalised_query)}%"
    ).order(
      Arel.sql("similarity(name_normalised, #{connection.quote(normalised_query)}) DESC")
    )
  }

  # Only companies that are currently active sponsors
  scope :active_sponsors, -> {
    joins(:sponsor_licences).where(sponsor_licences: { status: "active" }).distinct
  }

  # -----------------------------------------------------------------------
  # Instance helpers
  # -----------------------------------------------------------------------

  def active_sponsor?
    sponsor_licences.active.any?
  end

  def active_licences
    sponsor_licences.active
  end

  def routes
    sponsor_licences.active.pluck(:route).uniq.sort
  end

  # Returns "London" or "London, England" depending on what's available
  def location
    [town, county].compact.reject(&:blank?).join(", ").presence
  end

  # -----------------------------------------------------------------------
  # FriendlyId
  # -----------------------------------------------------------------------

  def should_generate_new_friendly_id?
    name_changed? || super
  end

  private

  def normalise_name
    return if name.blank?

    cleaned = name.strip.gsub(/\s+/, " ")
    self.name = cleaned
    self.name_normalised = cleaned.downcase
  end

  def sanitise_location(value)
    cleaned = value.to_s.strip
    return nil if cleaned.blank? || cleaned.casecmp(NULL_SENTINEL).zero?

    cleaned
  end
end
