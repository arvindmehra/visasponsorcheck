class HomeController < ApplicationController
  def index
    @active_companies_count = Company.active_sponsors.count
    @last_sync              = SponsorImportLog.done.recent.first
    @top_cities             = Company.top_cities(10)
    @visa_routes            = Company.top_routes(5)
    @top_sectors            = SicSector.ranked(limit: 8, only_populated: true)

    if @last_sync
      recent_events   = SponsorChangeEvent.where(occurred_at: 24.hours.ago..)
      @new_count      = recent_events.additions.count
      @updated_count  = recent_events.changes_only.count
      @removed_count  = recent_events.removals.count
    end

    set_meta_tags(
      title: "UK Visa Sponsor Register #{Date.current.year} | Search Licensed Sponsors",
      description: "Search #{number_with_delimiter(@active_companies_count)} UK companies with a Skilled Worker sponsor licence. Check if any employer is on the UKVI register of licensed sponsors — updated from GOV.UK.",
      canonical: root_url,
      og: {
        title: "UK Visa Sponsor Registry #{Date.current.year}",
        description: "Search #{number_with_delimiter(@active_companies_count)} licensed UK visa sponsors. Check if any company can sponsor a Skilled Worker or Health & Care Worker visa."
      }
    )
  end
end
