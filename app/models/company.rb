class Company < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # The gov.uk CSV sometimes contains the literal string "NULL" for empty
  # location fields. Sanitised on assignment.
  NULL_SENTINEL = "NULL"

  # Associations
  has_many :sponsor_licences, dependent: :destroy
  has_many :sponsor_change_events, -> { order(occurred_at: :desc) }, dependent: :destroy
  has_one :company_profile, dependent: :destroy

  # Validations
  validates :name, presence: true
  validates :name_normalised, presence: true
  validates :slug, presence: true, uniqueness: true

  # Callbacks
  before_validation :normalise_name

  # Sanitise location fields on write
  def town=(value)
    sanitised = sanitise_location(value)
    super(sanitised)
    # Keep normalised version in sync for city-slug routing
    write_attribute(:town_normalised, sanitised&.downcase&.strip)
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

    # Set threshold on the current connection
    connection.execute("SET pg_trgm.similarity_threshold = 0.15")

    where(
      "name_normalised % :q OR name_normalised ILIKE :partial",
      q: normalised_query,
      partial: "%#{sanitize_sql_like(normalised_query)}%"
    ).order(
      Arel.sql("name_normalised <-> #{connection.quote(normalised_query)}")
    )
  }

  # Only companies that are currently active sponsors
  scope :active_sponsors, -> {
    joins(:sponsor_licences).where(sponsor_licences: { status: "active" }).distinct
  }

  # Filter by normalised city slug (e.g. "london", "manchester")
  scope :by_city, ->(city_slug) {
    joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active" })
      .where(town_normalised: city_slug.to_s.downcase.strip)
      .distinct
  }

  # Filter by visa route (e.g. "Skilled Worker")
  scope :by_route, ->(route) {
    joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active", route: route })
      .distinct
  }

  # Filter by SIC industry sector key (see SicSector)
  scope :by_sector, ->(sector_key) {
    division_range = SicSector.division_range(sector_key)
    return none unless division_range

    joins(:sponsor_licences, :company_profile)
      .where(sponsor_licences: { status: "active" })
      .where("company_profiles.sic_code / 1000 BETWEEN ? AND ?", division_range.first, division_range.last)
      .distinct
  }

  # All active A-rated sponsors
  scope :a_rated, -> {
    joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active", rating: "A" })
      .distinct
  }

  # Companies with removed/revoked licences (and no active ones)
  scope :revoked, -> {
    where.not(id: joins(:sponsor_licences).where(sponsor_licences: { status: "active" }).select(:id))
      .joins(:sponsor_licences)
      .where(sponsor_licences: { status: "removed" })
      .distinct
  }

  # Returns a sorted list of distinct clean city slugs (for sitemap + directory page)
  def self.distinct_cities
    where.not(town_normalised: [ nil, "" ])
      .where("town_normalised ~ '^[a-z][a-z -]+$'")  # only clean alpha slugs
      .where("LENGTH(town_normalised) >= 2")
      .distinct
      .pluck(:town_normalised)
      .sort
  end

  # Returns the top cities by company record count in descending order
  def self.top_cities(limit = 10)
    where.not(town_normalised: [ nil, "" ])
      .where("town_normalised ~ '^[a-z][a-z -]+$'")  # only clean alpha slugs
      .where("LENGTH(town_normalised) >= 2")
      .group(:town_normalised)
      .order(Arel.sql("count(*) DESC, town_normalised ASC"))
      .limit(limit)
      .pluck(:town_normalised)
  end

  # Returns all distinct visa routes with active sponsors
  def self.distinct_routes
    SponsorLicence.active.distinct.pluck(:route).sort
  end

  # Returns the top visa routes by distinct active-company count, descending
  def self.top_routes(limit = 5)
    joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active" })
      .group("sponsor_licences.route")
      .order(Arel.sql("COUNT(DISTINCT companies.id) DESC, sponsor_licences.route ASC"))
      .limit(limit)
      .pluck(Arel.sql("sponsor_licences.route"))
  end

  # Returns the top cities for a single visa route, by active-company count
  def self.top_cities_for_route(route, limit = 5)
    joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active", route: route })
      .where.not(town_normalised: [ nil, "" ])
      .where("town_normalised ~ '^[a-z][a-z -]+$'")
      .group(:town_normalised)
      .order(Arel.sql("count(*) DESC, town_normalised ASC"))
      .limit(limit)
      .pluck(:town_normalised)
  end

  # Up to `limit` other active sponsors related to this one — same city
  # first (via the indexed town_normalised column), then topped up with
  # same-visa-route sponsors (via the indexed route column) if the city
  # doesn't yield enough on its own. Gives every company profile page
  # several genuine outbound links instead of relying on a single "back to
  # directory" link, so pages aren't orphaned dead ends.
  def self.related_to(company, limit: 5)
    related = []

    if company.city_slug.present?
      related += by_city(company.city_slug)
        .where.not(id: company.id)
        .includes(:sponsor_licences)
        .order(:name)
        .limit(limit)
        .to_a
    end

    remaining = limit - related.size
    primary_route = company.routes.first
    if remaining > 0 && primary_route.present?
      related += by_route(primary_route)
        .where.not(id: related.map(&:id) + [ company.id ])
        .includes(:sponsor_licences)
        .order(:name)
        .limit(remaining)
        .to_a
    end

    related
  end

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
    [ town, county ].compact.reject(&:blank?).join(", ").presence
  end

  # City slug for building city landing page URLs (e.g. "london")
  def city_slug
    town_normalised.presence
  end

  # Auto-generated unique summary sentence for SEO (prevents thin content flag)
  def seo_summary
    parts = []
    licences = sponsor_licences.active.order(:route)
    if licences.any?
      rating  = licences.first.rating
      routes  = licences.pluck(:route).uniq.to_sentence
      city    = location.presence || "the UK"
      last_ok = licences.maximum(:last_seen_at)&.strftime("%B %Y")
      parts << "#{name} is #{rating == 'A' ? 'an A-rated' : 'a B-rated'} UK visa sponsor based in #{city},"
      parts << "licensed to sponsor workers on the #{routes} route#{'s' if licences.size > 1}."
      parts << "Their licence was last verified against the GOV.UK register in #{last_ok}." if last_ok
    else
      parts << "#{name} was previously listed on the UK visa sponsor register but has since been removed."
    end
    parts.join(" ")
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
