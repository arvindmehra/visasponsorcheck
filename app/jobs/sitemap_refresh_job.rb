class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    # Generate the sitemap xml
    begin
      Rake::Task["sitemap:clean"].invoke
    rescue => e
      Rails.logger.error("Sitemap clean failed: #{e.message}")
    end

    begin
      Rake::Task["sitemap:create"].invoke
    rescue => e
      Rails.logger.error("Sitemap create failed: #{e.message}")
    end
  end
end
