module SponsorsHelper
  # Pill badge with a status dot, used for the "Status" column on every
  # sponsor listing table (city/sector/route/a-rated/revoked) and the
  # per-licence table on a company's show page.
  def sponsor_status_badge(active)
    if active
      content_tag(:span, class: "inline-flex items-center gap-1.5 rounded-full bg-emerald-50 px-2.5 py-1 text-xs font-semibold text-emerald-700 border border-emerald-200") do
        concat content_tag(:span, "", class: "h-1.5 w-1.5 rounded-full bg-emerald-500")
        concat "Active"
      end
    else
      content_tag(:span, class: "inline-flex items-center gap-1.5 rounded-full bg-slate-100 px-2.5 py-1 text-xs font-semibold text-slate-500 border border-slate-200") do
        concat content_tag(:span, "", class: "h-1.5 w-1.5 rounded-full bg-slate-400")
        concat "Removed"
      end
    end
  end

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
        rating_word(ratings.first)
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

  # Additional regional/industry/verification paragraphs for a company's show
  # page, driven by the templates in config/locales/en.yml under
  # "company_profile". These render synchronously (unlike the enrichment
  # cards, which lazy-load via Turbo Frame and may not be present in the
  # initial HTML crawlers see), so they carry the actual weight of pushing
  # each profile page past a thin-content word count on their own.
  #
  # Rotated by company.id — deterministic per company, varied across the
  # ~126,000 companies that would otherwise share near-identical copy.
  def company_expanded_profile_paragraphs(company, licences = company.sponsor_licences)
    active_licences = licences.select { |l| l.status == "active" }
    city = company.location.presence || "the UK"

    paragraphs = []

    regional_template = I18n.t("company_profile.regional_context")[company.id % 4]
    paragraphs << (regional_template % { company_name: company.name, city: city })

    if active_licences.any?
      route = active_licences.map(&:route).uniq.to_sentence
      industry_template = I18n.t("company_profile.industry_context")[company.id % 4]
      paragraphs << (industry_template % { company_name: company.name, route: route })
    end

    status_clause = if active_licences.any?
      "#{company.name}'s licence is currently shown as active on our records."
    else
      "#{company.name}'s licence is currently shown as removed from the register on our records."
    end
    verification_template = I18n.t("company_profile.verification_note")[company.id % 3]
    paragraphs << (verification_template % { status_clause: status_clause })

    paragraphs
  end

  # Short descriptive phrase for a licence rating, used in generated summary
  # text. "Provisional" licences (Global Business Mobility: UK Expansion
  # Worker route) aren't A/B rated at all, so they get their own phrasing
  # rather than being lumped in with "B-rated".
  def rating_word(rating)
    case rating
    when "A" then "an A-rated"
    when "B" then "a B-rated"
    else "a Provisional"
    end
  end

  # Rating badge — a small square for the standard A/B letter grades, or a
  # wider pill for non-letter ratings like "Provisional" (the Global Business
  # Mobility: UK Expansion Worker route, which GOV.UK doesn't give an A/B
  # compliance rating at all). Used everywhere a licence's rating is shown:
  # city/sector/route listing tables and the company show page.
  def rating_badge(rating)
    case rating
    when "A"
      content_tag(:span, "A", class: "inline-flex h-6 w-6 items-center justify-center rounded-md text-xs font-bold border bg-emerald-50 border-emerald-200 text-emerald-700")
    when "B"
      content_tag(:span, "B", class: "inline-flex h-6 w-6 items-center justify-center rounded-md text-xs font-bold border bg-amber-50 border-amber-200 text-amber-700")
    else
      content_tag(:span, rating, class: "inline-flex h-6 items-center justify-center rounded-md px-2 text-xs font-bold border bg-slate-50 border-slate-200 text-slate-600 whitespace-nowrap")
    end
  end
end
