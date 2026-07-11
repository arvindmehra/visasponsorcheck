class CompanyProfile < ApplicationRecord
  belongs_to :company

  # Human-readable labels for Companies House company_type codes
  COMPANY_TYPE_LABELS = {
    "ltd" => "Private Limited Company",
    "plc" => "Public Limited Company",
    "llp" => "Limited Liability Partnership",
    "private-unlimited" => "Private Unlimited Company",
    "old-public-company" => "Old Public Company",
    "private-limited-guarant-nsc-limited-exemption" => "Private Limited by Guarantee (Exempt)",
    "private-limited-guarant-nsc" => "Private Limited by Guarantee",
    "private-limited-shares-section-30-exemption" => "Private Limited (Section 30 Exempt)",
    "protected-cell-company" => "Protected Cell Company",
    "assurance-company" => "Assurance Company",
    "oversea-company" => "Overseas Company",
    "eeig" => "European Economic Interest Grouping",
    "icvc-securities" => "Investment Company with Variable Capital (Securities)",
    "icvc-warrant" => "Investment Company with Variable Capital (Warrant)",
    "icvc-umbrella" => "Investment Company with Variable Capital (Umbrella)",
    "registered-society-non-jurisdictional" => "Registered Society",
    "industrial-and-provident-society" => "Industrial and Provident Society",
    "northern-ireland" => "Northern Ireland Company",
    "northern-ireland-other" => "Northern Ireland Other",
    "royal-charter" => "Royal Charter Company",
    "investment-company-with-variable-capital" => "Investment Company with Variable Capital",
    "unregistered-company" => "Unregistered Company",
    "limited-partnership" => "Limited Partnership",
    "scottish-partnership" => "Scottish Partnership",
    "charitable-incorporated-organisation" => "Charitable Incorporated Organisation",
    "scottish-charitable-incorporated-organisation" => "Scottish Charitable Incorporated Organisation",
    "further-education-or-sixth-form-college-corporation" => "Further Education Corporation",
    "community-interest-company" => "Community Interest Company",
    "registered-overseas-entity" => "Registered Overseas Entity"
  }.freeze

  # Human-readable label for this company's type
  def company_type_label
    COMPANY_TYPE_LABELS[company_type] || company_type&.titleize&.gsub("-", " ")
  end

  # Formatted SIC display string, e.g. "62090 - Other information technology service activities"
  def sic_display
    return nil if sic_code.blank?

    if sic_code_description.present?
      "#{sic_code} - #{sic_code_description}"
    else
      sic_code.to_s
    end
  end
end
