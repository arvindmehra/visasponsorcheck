class PagesController < ApplicationController
  def faq
    set_meta_tags(
      title: "UK Visa Sponsor FAQ | What Is a Sponsor Licence & How to Check",
      description: "Answers to common questions about UK visa sponsor licences: what A-rating means, how to check if a company can sponsor a visa, tier 2 sponsors, and more.",
      canonical: faq_url
    )
  end
end
