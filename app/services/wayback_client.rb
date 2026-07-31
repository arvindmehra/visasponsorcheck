require "httparty"
require "tempfile"
require "json"

# Thin client for the Internet Archive's Wayback Machine — used to backfill
# historical sponsor register data from before this app started its own
# daily tracking. Two things it does:
#   1. list_snapshots  — ask the CDX API which distinct captures of a URL exist
#   2. fetch            — download the archived content of one specific capture
#
# This queries archive.org's own public API against GOV.UK's primary-source
# pages/attachments — not a third party's derived product — see the
# discussion that led here for why that distinction matters.
class WaybackClient
  CDX_BASE_URL = "https://web.archive.org/cdx/search/cdx".freeze
  ARCHIVE_BASE_URL = "https://web.archive.org/web".freeze

  # Returns [{ timestamp:, url: }, ...] for every distinct-by-content capture
  # of `url` that returned HTTP 200, oldest first. `from`/`to` are optional
  # "YYYYMMDD" bounds.
  def self.list_snapshots(url:, from: nil, to: nil)
    query = {
      url: url,
      output: "json",
      fl: "timestamp,original",
      collapse: "digest",
      filter: "statuscode:200"
    }
    query[:from] = from if from
    query[:to] = to if to

    response = HTTParty.get(CDX_BASE_URL, query: query, timeout: 60)
    raise "Wayback CDX query failed for #{url} (HTTP #{response.code})" unless response.code == 200

    rows = JSON.parse(response.body)
    return [] if rows.blank? || rows.size <= 1 # header row only, or empty result

    rows.drop(1).map { |timestamp, original| { timestamp: timestamp, url: original } }
  end

  # Downloads the archived version of `original_url` as captured at
  # `timestamp` to a temp file, returning its path. Caller is responsible
  # for deleting it.
  def self.fetch(timestamp:, original_url:)
    archive_url = "#{ARCHIVE_BASE_URL}/#{timestamp}/#{original_url}"
    extension = File.extname(URI.parse(original_url).path).presence || ".html"

    temp_file = Tempfile.new([ "wayback_snapshot", extension ])
    temp_file.binmode

    response = HTTParty.get(archive_url, stream_body: true, timeout: 120) do |fragment|
      temp_file.write(fragment)
    end
    temp_file.close

    unless response.code == 200
      temp_file.unlink
      raise "Failed to fetch Wayback snapshot #{archive_url} (HTTP #{response.code})"
    end

    temp_file.path
  end
end
