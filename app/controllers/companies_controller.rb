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
    end
  end
end
