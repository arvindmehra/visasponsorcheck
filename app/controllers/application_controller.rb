class ApplicationController < ActionController::Base
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  # Set site-wide default meta tags (overridden per page via set_meta_tags)
  before_action :set_default_meta_tags

  private

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
