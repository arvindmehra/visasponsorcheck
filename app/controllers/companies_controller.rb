class CompaniesController < ApplicationController
  def show
    @company = Company.friendly.find(params[:id])

    # Cache key incorporating company state, licences, and change events
    cache_key = [
      @company,
      @company.sponsor_licences.maximum(:updated_at),
      @company.sponsor_change_events.maximum(:updated_at)
    ]
    last_modified = [
      @company.updated_at,
      @company.sponsor_licences.maximum(:updated_at),
      @company.sponsor_change_events.maximum(:updated_at)
    ].compact.max

    if stale?(etag: cache_key, last_modified: last_modified, public: true)
      @sponsor_licences = @company.sponsor_licences.order(:route)
      @change_events = @company.sponsor_change_events.includes(:sponsor_import_log).recent

      # Build keyword-rich meta tags from real data
      rating_label = @company.active_licences.first&.rating
      routes_label = @company.routes.to_sentence.presence || "various routes"
      city_label   = @company.location.presence || "UK"

      title_str = "#{@company.name} — UK Visa Sponsor | #{city_label}"
      title_str = title_str.truncate(60)

      desc_str = "Check if #{@company.name} (#{city_label}) is a licensed UK visa sponsor. " \
                 "#{rating_label ? "#{rating_label}-rated" : 'Previously listed'} sponsor for #{routes_label}. " \
                 "Verified from the official GOV.UK register."
      desc_str = desc_str.truncate(155)

      set_meta_tags(
        title: title_str,
        description: desc_str,
        canonical: company_url(@company),
        og: {
          title: "#{@company.name} — UK Visa Sponsor Status",
          description: desc_str
        }
      )
    end
  end
end
