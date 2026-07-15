class ApplicationController < ActionController::Base
  include Pagy::Backend
  include ActionView::Helpers::NumberHelper

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set site-wide default meta tags (overridden per page via set_meta_tags)
  before_action :set_default_meta_tags

  # A page param past the last real page (stale bookmark, crawler probing
  # ?page=N past the end, hand-edited URL) previously surfaced as an
  # unhandled 500 — Pagy raises here rather than clamping automatically.
  # Treat it the same as any other not-found listing page.
  rescue_from Pagy::OverflowError, with: :render_not_found

  private

  def render_not_found
    render file: "public/404.html", status: :not_found
  end

  def set_default_meta_tags
    set_meta_tags(
      site: "VisaSponsorUK",
      separator: "|",
      og: {
        type: "website",
        site_name: "VisaSponsorUK"
      }
    )
  end
end
