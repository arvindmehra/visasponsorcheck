require "nokogiri"

# Finds every distinct version of the GOV.UK sponsor register CSV that the
# Wayback Machine has archived, from when the register switched from PDF to
# CSV (confirmed via CDX research: ~Dec 2021) up to now.
#
# The CDX API only indexes the HTML publication page directly (that's a
# fixed URL we can query); the CSV attachment itself lives at a different
# URL that changes every time UKVI re-publishes it. So this walks each
# archived HTML capture, extracts whatever CSV link it pointed to at that
# time (same href-scraping approach as SponsorCsvDownloader#scrape_csv_url,
# just applied to an archived copy of the page instead of the live one),
# and collapses consecutive captures that point at the identical CSV down
# to a single entry — most nearby captures are the same underlying register
# version, re-crawled before the next real update.
class SponsorHistorySnapshotFinder
  REGISTER_PAGE_URL = "https://www.gov.uk/government/publications/register-of-licensed-sponsors-workers".freeze
  # The register was still a PDF before this; see CLAUDE.md-adjacent research
  # notes / conversation history for how this date was established.
  CSV_ERA_START = "20211201".freeze

  def self.call(from: CSV_ERA_START, to: nil)
    new(from: from, to: to).call
  end

  def initialize(from:, to:)
    @from = from
    @to = to
  end

  # Returns [{ csv_url:, wayback_timestamp: }, ...], oldest first, one entry
  # per distinct register version (not per capture).
  def call
    page_snapshots = WaybackClient.list_snapshots(url: REGISTER_PAGE_URL, from: @from, to: @to)

    versions = []
    last_csv_url = nil

    page_snapshots.each do |snapshot|
      csv_url = extract_csv_url(snapshot)
      next if csv_url.blank?
      next if csv_url == last_csv_url

      versions << { csv_url: csv_url, wayback_timestamp: snapshot[:timestamp] }
      last_csv_url = csv_url
    end

    versions
  end

  private

  def extract_csv_url(snapshot)
    html_path = WaybackClient.fetch(timestamp: snapshot[:timestamp], original_url: snapshot[:url])
    link = find_csv_link(File.read(html_path))
    File.delete(html_path) if File.exist?(html_path)
    link
  rescue => e
    Rails.logger.warn("SponsorHistorySnapshotFinder: skipping #{snapshot[:timestamp]} (#{e.message})")
    nil
  end

  def find_csv_link(html)
    doc = Nokogiri::HTML(html)
    href = doc.css("a").map { |a| a["href"] }.compact.find { |link| link.include?(".csv") }
    return nil if href.blank?

    # Wayback rewrites hrefs to "/web/{timestamp}/{original_url}" (or an
    # absolute equivalent) — strip that so identical underlying CSVs
    # normalise to the same value regardless of which capture pointed to them.
    href.sub(%r{\A(https?://web\.archive\.org)?/web/\d+[a-z_]*/}, "")
  end
end
