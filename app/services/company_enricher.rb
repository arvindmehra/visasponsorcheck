class CompanyEnricher
  def self.enrich!(company)
    return company if company.enriched_at.present?

    # 1. Query Companies House API
    result = CompaniesHouseClient.search_by_name(company.name)
    
    # 2. Update company details (always set enriched_at so we cache the lookup attempt)
    if result
      company.update(
        company_number: result[:company_number],
        registered_office_address: result[:address],
        enriched_at: Time.current
      )
    else
      company.update(
        enriched_at: Time.current
      )
    end
    
    company
  rescue => e
    Rails.logger.error("Enrichment failed for #{company.name}: #{e.message}")
    company
  end
end
