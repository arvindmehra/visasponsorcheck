require "sitemap_generator"

# Custom adapter to perform atomic writes, avoiding a transient state where
# the file is partially written while crawlers fetch it.
class ::SitemapGenerator::AtomicFileAdapter < ::SitemapGenerator::FileAdapter
  def write(location, raw_data)
    # Ensure that the directory exists
    dir = location.directory
    if !File.exist?(dir)
      FileUtils.mkdir_p(dir)
    elsif !File.directory?(dir)
      raise SitemapError.new("#{dir} should be a directory!")
    end

    # Define a temporary path in the same directory
    dest_path = location.path
    temp_path = "#{dest_path}.tmp"

    # Write to the temp file
    stream = File.open(temp_path, "wb")
    if location.path.to_s =~ /.gz$/
      gzip(stream, raw_data)
    else
      plain(stream, raw_data)
    end

    # Atomically rename/move the temp file to the destination path
    File.rename(temp_path, dest_path)
  end
end

::SitemapGenerator::Sitemap.adapter = ::SitemapGenerator::AtomicFileAdapter.new

SitemapGenerator::Sitemap.default_host = "https://visasponsoruk.com"
SitemapGenerator::Sitemap.sitemaps_host = "https://visasponsoruk.com"
SitemapGenerator::Sitemap.public_path  = "public/"
SitemapGenerator::Sitemap.sitemaps_path = "sitemaps/"  # puts sitemap.xml.gz at /sitemaps/sitemap.xml.gz
SitemapGenerator::Sitemap.compress = true


SitemapGenerator::Sitemap.create do
  # Segmented into named sub-sitemaps (sitemap-core.xml.gz,
  # sitemap-sponsors-active.xml.gz, etc.) rather than the default arbitrary
  # sitemap1.xml.gz/sitemap2.xml.gz numbering. Google Search Console reports
  # indexing coverage per submitted sitemap file, so naming each one after
  # the data state it represents makes it possible to see, at a glance,
  # whether e.g. active sponsor pages are indexing cleanly while revoked ones
  # lag — instead of one undifferentiated coverage number across all 126k+
  # URLs. A company page can legitimately appear in more than one group
  # (e.g. an active sponsor that also changed in the latest sync) — that's
  # expected; sitemaps aren't a strict partition, each group is just a
  # monitoring lens.
  group(filename: "sitemap-core") do
    # Static + structural pages
    add "/",                         changefreq: "daily",   priority: 1.0
    add "/sponsors",                 changefreq: "weekly",  priority: 0.9
    add "/uk-visa-sponsorship-list", changefreq: "weekly",  priority: 0.9
    add "/faq",                      changefreq: "monthly", priority: 0.7
    add "/sponsors/a-rated",         changefreq: "weekly",  priority: 0.8
    add "/sponsors/revoked",         changefreq: "weekly",  priority: 0.7
    add "/sponsors/sectors",         changefreq: "weekly",  priority: 0.8
    add "/sponsors/locations",       changefreq: "weekly",  priority: 0.8

    # Visa route pages
    puts "Adding route pages..."
    SponsorLicence.active.distinct.pluck(:route).sort.each do |route|
      route_slug = route.downcase.gsub(/\s+/, "-")
      add "/sponsors/visa-route/#{route_slug}", changefreq: "weekly", priority: 0.8
    end

    # City pages — only cities with 3+ active sponsors (quality threshold)
    puts "Adding city pages..."
    Company
      .joins(:sponsor_licences)
      .where(sponsor_licences: { status: "active" })
      .where.not(town_normalised: [ nil, "" ])
      .group(:town_normalised)
      .having("COUNT(DISTINCT companies.id) >= 3")
      .pluck(:town_normalised)
      .sort
      .each do |city_slug|
        add "/sponsors/city/#{city_slug}", changefreq: "weekly", priority: 0.8
      end

    # Industry sector pages — only sectors with 3+ active sponsors (quality threshold)
    puts "Adding sector pages..."
    SicSector.ranked(only_populated: true).each do |sector|
      next if sector[:count] < 3
      add "/sponsors/sector/#{sector[:key]}", changefreq: "weekly", priority: 0.8
    end
  end

  # Individual company pages currently holding at least one active licence —
  # the bulk of the ~126,000 company pages.
  group(filename: "sitemap-sponsors-active") do
    puts "Adding active sponsor company pages..."
    Company.active_sponsors.select(:id, :slug, :updated_at).find_each(batch_size: 1000) do |company|
      add "/sponsor/#{company.slug}", lastmod: company.updated_at, changefreq: "monthly", priority: 0.6
    end
  end

  # Companies with no active licence left (fully revoked/removed) — rarely
  # need re-crawling, so a lower changefreq/priority than active sponsors.
  group(filename: "sitemap-sponsors-removed") do
    puts "Adding removed sponsor company pages..."
    Company.revoked.select(:id, :slug, :updated_at).find_each(batch_size: 1000) do |company|
      add "/sponsor/#{company.slug}", lastmod: company.updated_at, changefreq: "yearly", priority: 0.3
    end
  end

  # Companies with a licence change (added/updated/removed) in the most
  # recently completed sync — the pages most worth an immediate re-crawl,
  # matching what the homepage's "Today's Register" cards and
  # /sponsors/recent/:type already surface.
  group(filename: "sitemap-sponsors-recently-updated") do
    puts "Adding recently-updated sponsor company pages..."
    last_sync = SponsorImportLog.done.recent.first
    if last_sync
      changed_company_ids = SponsorChangeEvent.where(sponsor_import_log: last_sync).distinct.pluck(:company_id)
      Company.where(id: changed_company_ids).select(:id, :slug, :updated_at).find_each(batch_size: 1000) do |company|
        add "/sponsor/#{company.slug}", lastmod: company.updated_at, changefreq: "daily", priority: 0.7
      end
    end
  end
end
