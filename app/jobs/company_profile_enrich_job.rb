class CompanyProfileEnrichJob < ApplicationJob
  queue_as :default

  def perform(company_id)
    company = Company.find_by(id: company_id)
    return unless company

    CompanyProfileEnricher.enrich!(company)
  end
end
