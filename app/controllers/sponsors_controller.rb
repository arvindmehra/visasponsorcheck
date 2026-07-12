class SponsorsController < ApplicationController
  include Pagy::Backend

  # GET /sponsors
  def index
    @cities = Company.distinct_cities.first(50) # Top 50 cities for internal links
    @visa_routes = Company.distinct_routes
    @top_sectors = SicSector.ranked(limit: 12, only_populated: true)
    @active_count = Company.active_sponsors.count

    set_meta_tags(
      title: "UK Visa Sponsor List #{Date.current.year} | Register of Licensed Sponsors",
      description: "Browse the full register of #{number_with_delimiter(@active_count)} licensed UK visa sponsors. Search by city, visa route (Skilled Worker, Health & Care), or rating.",
      canonical: sponsors_url
    )
  end

  # GET /sponsors/locations
  def locations
    @cities = Company.distinct_cities
    @grouped_cities = @cities.map do |slug|
      name = slug.split("-").map(&:capitalize).join(" ")
      { name: name, slug: slug }
    end.sort_by { |c| c[:name] }.group_by { |c| c[:name][0].upcase }

    @active_count = Company.active_sponsors.count

    set_meta_tags(
      title: "UK Visa Sponsor Directory by Location | Licensed Companies A-Z",
      description: "Find licensed UK visa sponsors sorted alphabetically by city, town, or region. Browse and filter companies across all UK locations.",
      canonical: locations_sponsors_url
    )
  end

  # GET /sponsors/routes
  def routes
    @visa_routes = Company.distinct_routes
    @grouped_routes = @visa_routes.map do |route|
      { name: route, slug: route.downcase.gsub(/\s+/, "-") }
    end.group_by { |r| r[:name][0].upcase }

    @active_count = Company.active_sponsors.count

    set_meta_tags(
      title: "UK Visa Sponsor Directory by Visa Route | Licensed Companies A-Z",
      description: "Find licensed UK visa sponsors sorted alphabetically by visa route, from Skilled Worker to Health & Care Worker. Browse and filter companies by route type.",
      canonical: visa_routes_sponsors_url
    )
  end

  # GET /sponsors/city/:city
  def city
    @city_slug   = params[:city].to_s.downcase.strip
    @city_name   = @city_slug.split("-").map(&:capitalize).join(" ")
    @pagy, @companies = pagy(
      Company.by_city(@city_slug).includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.by_city(@city_slug).count

    if @count.zero?
      render file: "public/404.html", status: :not_found and return
    end

    title = "Visa Sponsors in #{@city_name} | UK Sponsor Licence List"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? city_sponsors_url(city: @city_slug, page: @pagy.page) : city_sponsors_url(city: @city_slug)

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} companies in #{@city_name} are licensed to sponsor UK work visas. Browse the full register of visa sponsors in #{@city_name}.",
      canonical: canonical_url
    )
  end

  # GET /sponsors/sectors
  def sectors
    @sectors = SicSector.ranked

    set_meta_tags(
      title: "UK Visa Sponsor Directory by Industry | Licensed Companies by Sector",
      description: "Find licensed UK visa sponsors by industry sector, from Manufacturing to Software & IT. Browse companies grouped by their registered SIC code.",
      canonical: sectors_sponsors_url
    )
  end

  # GET /sponsors/sector/:sector
  def sector
    @sector_key  = params[:sector].to_s.downcase.strip
    @sector_name = SicSector.name_for(@sector_key)

    if @sector_name.nil?
      render file: "public/404.html", status: :not_found and return
    end

    @pagy, @companies = pagy(
      Company.by_sector(@sector_key).includes(:sponsor_licences, :company_profile).order(:name),
      limit: 50
    )
    @count = Company.by_sector(@sector_key).count

    if @count.zero?
      render file: "public/404.html", status: :not_found and return
    end

    title = "#{@sector_name} Visa Sponsors UK | Licensed Sponsor Register"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? sector_sponsors_url(sector: @sector_key, page: @pagy.page) : sector_sponsors_url(sector: @sector_key)

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} UK companies in the #{@sector_name} sector are licensed to sponsor work visas. Browse the full register of #{@sector_name} visa sponsors.",
      canonical: canonical_url
    )
  end

  # GET /sponsors/route/:route
  def route
    @route_slug  = params[:route].to_s
    @route_name  = @route_slug.split("-").map(&:capitalize).join(" ")
    # Map slug "skilled-worker" -> "Skilled Worker"
    @route_name  = find_matching_route(@route_slug) || @route_name
    @pagy, @companies = pagy(
      Company.by_route(@route_name).includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.by_route(@route_name).count

    if @count.zero?
      render file: "public/404.html", status: :not_found and return
    end

    title = "#{@route_name} Visa Sponsors UK | Licensed Sponsor Register"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? visa_route_sponsors_url(route: @route_slug, page: @pagy.page) : visa_route_sponsors_url(route: @route_slug)

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} UK companies licensed to sponsor #{@route_name} visas. Full register of #{@route_name} sponsors from the official GOV.UK list.",
      canonical: canonical_url
    )
  end

  RECENT_TYPES = {
    "new" => { event_scope: :additions, label: "New" },
    "updated" => { event_scope: :changes_only, label: "Updated" },
    "removed" => { event_scope: :removals, label: "Removed" }
  }.freeze

  # GET /sponsors/recent/:type (type: new | updated | removed)
  # Shows licence changes from the most recent completed sync — matching the
  # counts shown in the homepage's "Today's Register" cards. Tied to the sync
  # itself (not a rolling 24h window), so a delayed/skipped sync still shows
  # that sync's real changes instead of going stale or blank. "Updated" is
  # any change except added/removed (rating, status, route, licence type).
  def recent
    @type = params[:type].to_s
    type_config = RECENT_TYPES[@type]

    if type_config.nil?
      render file: "public/404.html", status: :not_found and return
    end

    @last_sync = SponsorImportLog.done.recent.first

    if @last_sync.nil?
      render file: "public/404.html", status: :not_found and return
    end

    @label = type_config[:label]
    events_scope = SponsorChangeEvent.where(sponsor_import_log: @last_sync).public_send(type_config[:event_scope])

    @pagy, @events = pagy(events_scope.includes(:company).recent, limit: 50)
    @count = events_scope.count

    title = "#{@label} Sponsors — #{@last_sync.completed_at.strftime('%-d %B %Y')} Register Update"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? recent_sponsors_url(type: @type, page: @pagy.page) : recent_sponsors_url(type: @type)

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} UK visa sponsor licences were #{@type} in the #{@last_sync.completed_at.strftime('%-d %B %Y')} register update.",
      canonical: canonical_url
    )
  end

  # GET /sponsors/a-rated
  def a_rated
    @pagy, @companies = pagy(
      Company.a_rated.includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.a_rated.count

    title = "A-Rated UK Visa Sponsors List | Top Rated Sponsor Licences"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? a_rated_sponsors_url(page: @pagy.page) : a_rated_sponsors_url

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} UK companies hold an A-rated sponsor licence. A-rated sponsors have a clean compliance record with UKVI. Browse the full A-rated sponsor list.",
      canonical: canonical_url
    )
  end

  # GET /sponsors/revoked
  def revoked
    @pagy, @companies = pagy(
      Company.revoked.includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.revoked.count

    title = "Revoked Sponsor Licences UK | Removed from Register"
    title += " (Page #{@pagy.page})" if @pagy.page > 1
    canonical_url = @pagy.page > 1 ? revoked_sponsors_url(page: @pagy.page) : revoked_sponsors_url

    set_meta_tags(
      title: title,
      description: "#{number_with_delimiter(@count)} companies have had their UK sponsor licence revoked or removed. Check our revoked sponsor licence list sourced from GOV.UK.",
      canonical: canonical_url
    )
  end

  private

  def find_matching_route(slug)
    all_routes = SponsorLicence.distinct.pluck(:route)
    all_routes.find { |r| r.downcase.gsub(/\s+/, "-") == slug.downcase }
  end
end
