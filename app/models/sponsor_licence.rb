class SponsorLicence < ApplicationRecord
  # -----------------------------------------------------------------------
  # Constants
  # -----------------------------------------------------------------------

  STATUSES       = %w[active removed].freeze
  LICENCE_TYPES  = [ "Worker", "Temporary Worker" ].freeze
  RATINGS        = %w[A B].freeze

  # Parsed from "Type & Rating" CSV column e.g. "Worker (A rating)"
  TYPE_RATING_REGEX = /\A(.+?)\s*\(([AB])\s*rating\)\z/i

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
  # Returns { licence_type: "Worker", rating: "A" } or nil if unparseable.
  def self.parse_type_and_rating(raw)
    return nil if raw.blank?

    match = raw.strip.match(TYPE_RATING_REGEX)
    return nil unless match

    {
      licence_type: match[1].strip.split.map(&:capitalize).join(" "),
      rating: match[2].upcase
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
