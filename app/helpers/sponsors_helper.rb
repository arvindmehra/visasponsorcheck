module SponsorsHelper
  # Base paragraph built from the company's sponsor licence data (rating, routes, status).
  # Rotates across three templates keyed off company.id to avoid duplicate-content text
  # across the many companies that share similar licence data.
  def company_licence_summary_paragraph(company, licences = company.sponsor_licences)
    active_licences = licences.select { |l| l.status == "active" }
    all_licences = licences.to_a
    last_seen = all_licences.map(&:last_seen_at).compact.max || company.updated_at
    formatted_date = last_seen.strftime("%B %-d, %Y")
    city = company.location.presence || "the UK"

    if active_licences.any?
      ratings = active_licences.map(&:rating).uniq.sort
      rating_phrase = if ratings.size == 1
        "#{ratings.first == 'A' ? 'an A-rated' : 'a B-rated'}"
      else
        "#{ratings.to_sentence}-rated"
      end

      routes = active_licences.map(&:route).uniq.sort
      routes_phrase = "#{routes.to_sentence} visa route#{'s' if routes.size > 1}"
      licence_word = active_licences.size > 1 ? "licences" : "licence"
      status_phrase = active_licences.size > 1 ? "These licences are currently active" : "This licence is currently active"

      case company.id % 3
      when 0
        "#{company.name} is a registered employer based in #{city}, holding #{rating_phrase} sponsor #{licence_word} for the #{routes_phrase}. #{status_phrase}. Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      when 1
        "Based in #{city}, #{company.name} is a licensed UK sponsor holding #{rating_phrase} #{licence_word} for the #{routes_phrase}. The current status of #{active_licences.size > 1 ? 'these licences' : 'this licence'} is active. Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      else
        "For the #{routes_phrase}, #{company.name} is an authorized sponsor with #{rating_phrase} #{licence_word}. Located in #{city}, this employer's #{licence_word} #{active_licences.size > 1 ? 'are' : 'is'} currently active. Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      end
    else
      # Inactive / Removed sponsor
      case company.id % 3
      when 0
        "#{company.name} was previously a registered employer based in #{city}, but its UK visa sponsor licence is currently inactive (removed). Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      when 1
        "The UK visa sponsor licence for #{company.name} (located in #{city}) has been removed from the official register and is currently inactive. Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      else
        "Based in #{city}, #{company.name} no longer holds an active sponsor licence on the UK visa register. This licence is currently inactive (removed). Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on #{formatted_date}."
      end
    end
  end

  # Separate, readable paragraph built purely from Companies House profile data
  # (incorporation date, company type, nature of business, current status).
  # Returns nil when the company has no enriched profile, so callers can skip
  # rendering an empty paragraph.
  def company_profile_paragraph(company)
    profile = company.company_profile
    return nil unless profile&.company_status.present?

    sentences = []

    incorporation_bits = []
    incorporation_bits << "was incorporated on #{profile.date_of_creation.strftime('%-d %B %Y')}" if profile.date_of_creation.present?
    incorporation_bits << "is registered as a #{profile.company_type_label}" if profile.company_type.present?
    sentences << "According to Companies House, #{company.name} #{incorporation_bits.join(' and ')}." if incorporation_bits.any?

    sentences << "Its registered nature of business is #{profile.sic_code_description}." if profile.sic_code_description.present?
    sentences << "Companies House currently lists its status as #{profile.company_status.humanize.downcase}."

    sentences.join(" ")
  end

  # Combined single-string summary (licence paragraph + profile paragraph), for contexts
  # that need one string field, e.g. structured data / meta descriptions.
  def company_summary_paragraph(company, licences = company.sponsor_licences)
    base = company_licence_summary_paragraph(company, licences)
    profile_text = company_profile_paragraph(company)
    profile_text.present? ? "#{base} #{profile_text}" : base
  end
end
