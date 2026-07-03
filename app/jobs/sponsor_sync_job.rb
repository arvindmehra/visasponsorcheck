class SponsorSyncJob < ApplicationJob
  queue_as :default

  def perform(*args)
    # Start the importer to sync the UK sponsor register
    SponsorImporter.call

    # Trigger sitemap regeneration
    SitemapRefreshJob.perform_later
  end
end

