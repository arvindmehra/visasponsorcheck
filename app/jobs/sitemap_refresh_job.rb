class SitemapRefreshJob < ApplicationJob
  queue_as :default

  def perform
    # Generate the sitemap xml
    Rake::Task["sitemap:clean"].invoke rescue nil
    Rake::Task["sitemap:create"].invoke rescue nil
  end
end
