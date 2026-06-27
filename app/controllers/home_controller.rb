class HomeController < ApplicationController
  def index
    @active_licences_count = SponsorLicence.active.count
    @active_companies_count = Company.active_sponsors.count
    @last_sync = SponsorImportLog.done.recent.first
  end
end
