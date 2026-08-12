class WeeklyBlogIngestionJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info("[WeeklyBlogIngestionJob] Starting weekly blog ingestion...")
    result = BlogGeneratorService.call

    if result[:success]
      Rails.logger.info("[WeeklyBlogIngestionJob] Successfully created blog draft: '#{result[:blog].title}' (Score: #{result[:quality_report][:score]})")
    else
      Rails.logger.warn("[WeeklyBlogIngestionJob] Blog ingestion completed with status: #{result[:error]}")
    end
  end
end
