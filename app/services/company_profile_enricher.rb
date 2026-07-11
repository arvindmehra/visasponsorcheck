class CompanyProfileEnricher
  def self.enrich!(company)
    return company if company.company_number.blank?
    return company if company.company_profile&.enriched_at.present?

    result = CompaniesHouseClient.fetch_profile(company.company_number)

    profile = company.company_profile || company.build_company_profile

    if result
      primary_sic = result[:sic_codes]&.first
      sic_description = primary_sic.present? ? SicCodeLookup.description_for(primary_sic) : nil

      profile.update!(
        company_status: result[:company_status],
        company_type: result[:company_type],
        date_of_creation: result[:date_of_creation],
        sic_code: primary_sic&.to_i,
        sic_code_description: sic_description,
        enriched_at: Time.current
      )
    else
      # Mark as enriched to avoid re-querying
      profile.update!(enriched_at: Time.current)
    end

    company
  rescue CompaniesHouseClient::RateLimitError
    raise
  rescue => e
    Rails.logger.error("Profile enrichment failed for #{company.name} (#{company.company_number}): #{e.message}")
    company
  end
end
