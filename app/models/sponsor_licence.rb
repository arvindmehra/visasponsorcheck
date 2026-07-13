class SponsorLicence < ApplicationRecord
  # -----------------------------------------------------------------------
  # Constants
  # -----------------------------------------------------------------------

  STATUSES       = %w[active removed].freeze
  LICENCE_TYPES  = [ "Worker", "Temporary Worker" ].freeze
  # "Provisional" covers routes GOV.UK doesn't give an A/B compliance rating
  # at all (currently only Global Business Mobility: UK Expansion Worker) —
  # see TYPE_RATING_REGEXES below.
  RATINGS        = %w[A B Provisional].freeze

  # Parsed from the "Type & Rating" CSV column. GOV.UK uses three shapes:
  #   "Worker (A rating)"                        -> standard A/B rating
  #   "Worker (A (Premium))"                      -> A/B rating with a sub-tier
  #                                                  annotation we don't store
  #   "Worker (UK Expansion Worker: Provisional)" -> no letter grade at all,
  #                                                  currently only seen on
  #                                                  the UK Expansion Worker
  #                                                  route
  TYPE_RATING_REGEXES = [
    /\A(.+?)\s*\(([AB])\s*rating\)\z/i,
    /\A(.+?)\s*\(([AB])\s*\([^)]*\)\)\z/i
  ].freeze
  PROVISIONAL_TYPE_REGEX = /\A(.+?)\s*\(.*?:\s*Provisional\s*\)\z/i

  # -----------------------------------------------------------------------
  # Associations
  # -----------------------------------------------------------------------

  belongs_to :company

  # -----------------------------------------------------------------------
  # Validations
  # -----------------------------------------------------------------------

  validates :organisation_name, presence: true
  validates :licence_type, presence: true, inclusion: { in: LICENCE_TYPES }
  validates :rating, presence: true, inclusion: { in: RATINGS }
  validates :route, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :first_seen_at, presence: true
  validates :last_seen_at, presence: true
  validates :route, uniqueness: { scope: :company_id,
                                  message: "already exists for this company" }

  # -----------------------------------------------------------------------
  # Scopes
  # -----------------------------------------------------------------------

  scope :active,   -> { where(status: "active") }
  scope :removed,  -> { where(status: "removed") }
  scope :by_route, ->(route) { where(route: route) }
  scope :workers,   -> { where(licence_type: "Worker") }
  scope :temporary, -> { where(licence_type: "Temporary Worker") }

  # -----------------------------------------------------------------------
  # Class helpers
  # -----------------------------------------------------------------------

  # Parse the raw "Type & Rating" CSV column into licence_type and rating.
  # Returns { licence_type: "Worker", rating: "A" } (or rating: "Provisional")
  # or nil if unparseable.
  def self.parse_type_and_rating(raw)
    return nil if raw.blank?

    cleaned = raw.strip

    TYPE_RATING_REGEXES.each do |regex|
      match = cleaned.match(regex)
      next unless match

      return {
        licence_type: match[1].strip.split.map(&:capitalize).join(" "),
        rating: match[2].upcase
      }
    end

    match = cleaned.match(PROVISIONAL_TYPE_REGEX)
    return nil unless match

    {
      licence_type: match[1].strip.split.map(&:capitalize).join(" "),
      rating: "Provisional"
    }
  end

  # -----------------------------------------------------------------------
  # Instance helpers
  # -----------------------------------------------------------------------

  def active?
    status == "active"
  end

  def removed?
    status == "removed"
  end

  def display_label
    "#{licence_type} – Route: #{route} (Rating #{rating})"
  end
end
