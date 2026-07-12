module ApplicationHelper
  include Pagy::Frontend

  # Appends "(Page X)" to a paginated collection's SEO title, but only past
  # page 1 — keeps the canonical first page's title clean while giving every
  # subsequent page a genuinely distinct <title> instead of duplicating it.
  def paginated_meta_title(base_title, pagy)
    return base_title unless pagy && pagy.page > 1
    "#{base_title} (Page #{pagy.page})"
  end

  # Appends page context to a paginated collection's meta description. Titles
  # already varied by page across these controllers, but the description
  # didn't — every page N reused page 1's exact description, which is the
  # actual duplicate-meta-description signal search consoles flag.
  def paginated_meta_description(base_description, pagy)
    return base_description unless pagy && pagy.page > 1
    "#{base_description} (Page #{pagy.page} of #{pagy.last})."
  end

  # Domains authoritative enough that we want to pass along their link-equity
  # signal rather than nofollow them. Matches the exact domain or any
  # subdomain (e.g. "find-and-update.company-information.service.gov.uk" and
  # "www.gov.uk" both match "gov.uk").
  TRUSTED_OUTBOUND_DOMAINS = [ "gov.uk" ].freeze

  # Renders an outbound link that drops rel="nofollow" for trusted government
  # domains (GOV.UK, Companies House) while keeping it for everything else
  # (LinkedIn, ad-hoc Google searches, etc.). "noopener" is always kept
  # regardless of trust, since that's a security property, not an SEO signal.
  def trusted_external_link_to(url, html_options = {}, &block)
    host = URI.parse(url).host.to_s
    trusted = TRUSTED_OUTBOUND_DOMAINS.any? { |domain| host == domain || host.end_with?(".#{domain}") }
    rel = trusted ? "noopener" : "noopener noreferrer nofollow"

    link_to(url, html_options.merge(target: "_blank", rel: rel), &block)
  end
end
