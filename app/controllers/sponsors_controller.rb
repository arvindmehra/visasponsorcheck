class SponsorsController < ApplicationController
  include Pagy::Backend

  # GET /sponsors
  def index
    @cities = Company.distinct_cities.first(50) # Top 50 cities for internal links
    @routes = Company.distinct_routes
    @active_count = Company.active_sponsors.count

    set_meta_tags(
      title: "UK Visa Sponsor List #{Date.current.year} | Register of Licensed Sponsors",
      description: "Browse the full register of #{number_with_delimiter(@active_count)} licensed UK visa sponsors. Search by city, visa route (Skilled Worker, Health & Care), or rating.",
      canonical: sponsors_url
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

    set_meta_tags(
      title: "Visa Sponsors in #{@city_name} | UK Sponsor Licence List",
      description: "#{number_with_delimiter(@count)} companies in #{@city_name} are licensed to sponsor UK work visas. Browse the full register of visa sponsors in #{@city_name}.",
      canonical: city_sponsors_url(city: @city_slug)
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

    set_meta_tags(
      title: "#{@route_name} Visa Sponsors UK | Licensed Sponsor Register",
      description: "#{number_with_delimiter(@count)} UK companies licensed to sponsor #{@route_name} visas. Full register of #{@route_name} sponsors from the official GOV.UK list.",
      canonical: route_sponsors_url(route: @route_slug)
    )
  end

  # GET /sponsors/a-rated
  def a_rated
    @pagy, @companies = pagy(
      Company.a_rated.includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.a_rated.count

    set_meta_tags(
      title: "A-Rated UK Visa Sponsors List | Top Rated Sponsor Licences",
      description: "#{number_with_delimiter(@count)} UK companies hold an A-rated sponsor licence. A-rated sponsors have a clean compliance record with UKVI. Browse the full A-rated sponsor list.",
      canonical: a_rated_sponsors_url
    )
  end

  # GET /sponsors/revoked
  def revoked
    @pagy, @companies = pagy(
      Company.revoked.includes(:sponsor_licences).order(:name),
      limit: 50
    )
    @count = Company.revoked.count

    set_meta_tags(
      title: "Revoked Sponsor Licences UK | Removed from Register",
      description: "#{number_with_delimiter(@count)} companies have had their UK sponsor licence revoked or removed. Check our revoked sponsor licence list sourced from GOV.UK.",
      canonical: revoked_sponsors_url
    )
  end

  private

  def find_matching_route(slug)
    all_routes = SponsorLicence.distinct.pluck(:route)
    all_routes.find { |r| r.downcase.gsub(/\s+/, "-") == slug.downcase }
  end
end
