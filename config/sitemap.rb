SitemapGenerator::Sitemap.default_host = "https://visasponsoruk.com"
SitemapGenerator::Sitemap.sitemaps_host = "https://visasponsoruk.com"
SitemapGenerator::Sitemap.public_path  = "public/"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"  # puts sitemap.xml.gz at /sitemaps/sitemap.xml.gz
SitemapGenerator::Sitemap.compress = true


SitemapGenerator::Sitemap.create do
  # Static pages
  add "/",          changefreq: "daily",   priority: 1.0
  add "/sponsors",  changefreq: "weekly",  priority: 0.9
  add "/faq",       changefreq: "monthly", priority: 0.7
  add "/sponsors/a-rated",  changefreq: "weekly", priority: 0.8
  add "/sponsors/revoked",  changefreq: "weekly", priority: 0.7

  # Visa route pages
  puts "Adding route pages..."
  SponsorLicence.active.distinct.pluck(:route).sort.each do |route|
    route_slug = route.downcase.gsub(/\s+/, "-")
    add "/sponsors/route/#{route_slug}", changefreq: "weekly", priority: 0.8
  end

  # City pages — only cities with 3+ active sponsors (quality threshold)
  puts "Adding city pages..."
  Company
    .joins(:sponsor_licences)
    .where(sponsor_licences: { status: "active" })
    .where.not(town_normalised: [nil, ""])
    .group(:town_normalised)
    .having("COUNT(DISTINCT companies.id) >= 3")
    .pluck(:town_normalised)
    .sort
    .each do |city_slug|
      add "/sponsors/city/#{city_slug}", changefreq: "weekly", priority: 0.8
    end

  # Individual company pages — batched for memory efficiency
  puts "Adding company pages..."
  Company.select(:id, :slug, :updated_at).find_each(batch_size: 1000) do |company|
    add "/sponsor/#{company.slug}",
        lastmod: company.updated_at,
        changefreq: "monthly",
        priority: 0.6
  end
end
