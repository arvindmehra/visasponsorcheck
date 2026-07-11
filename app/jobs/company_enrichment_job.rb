class CompanyEnrichmentJob < ApplicationJob
  queue_as :default

  # Companies House allows ~600 requests / 5 minutes. Serialising these jobs
  # (one company at a time, each making up to 2 requests, plus the sleep below)
  # keeps us well under that regardless of how many companies are enqueued at once.
  limits_concurrency to: 1, key: "companies_house_api", duration: 5.minutes

  def perform(company_id)
    company = Company.find_by(id: company_id)
    return unless company

    CompanyEnricher.enrich!(company)
    CompanyProfileEnricher.enrich!(company)

    sleep(0.5)
  end
end
