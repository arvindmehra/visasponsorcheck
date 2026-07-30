class PagesController < ApplicationController
  def faq
    set_meta_tags(
      title: "UK Visa Sponsor FAQ | What Is a Sponsor Licence & How to Check",
      description: "Answers to common questions about UK visa sponsor licences: what A-rating means, how to check if a company can sponsor a visa, tier 2 sponsors, and more.",
      canonical: faq_url
    )
  end

  def about
    set_meta_tags(
      title: "About VisaSponsorUK | UK Visa Sponsor Register",
      description: "How VisaSponsorUK tracks the official GOV.UK register of licensed UK visa sponsors, what a sponsor licence and A-rating mean, and how the data is kept up to date.",
      canonical: about_url
    )
  end

  def contact
    set_meta_tags(
      title: "Contact VisaSponsorUK",
      description: "Get in touch with VisaSponsorUK.",
      canonical: contact_url
    )
  end

  # GET /uk-visa-sponsorship-list
  # Informational/explainer page — distinct from the transactional /sponsors
  # browse tool. Owns the "sponsorship" keyword phrasing (sponsorship list,
  # sponsorship visa uk, uk sponsorship companies) so it doesn't compete with
  # /sponsors' "sponsor list" title/meta for the same SERP slot.
  def sponsorship_list_guide
    @active_count = Company.active_sponsors.count
    @rating_breakdown = SponsorLicence.active.group(:rating).count
    @top_routes = Company.top_routes(5)
    @top_cities = Company.top_cities(10)
    @last_sync = SponsorImportLog.done.recent.first

    set_meta_tags(
      title: "UK Visa Sponsorship List Explained | How Sponsorship Works (#{Date.current.year})",
      description: "What the UK visa sponsorship list actually is, how it's compiled from the official GOV.UK register, and how to find out which companies can sponsor you. #{number_with_delimiter(@active_count)} companies currently listed.",
      canonical: sponsorship_list_guide_url
    )
  end
end
