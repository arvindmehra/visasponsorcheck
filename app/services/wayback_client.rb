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

  # archive.org intermittently 503s (and occasionally 429s) under load,
  # especially for CDX queries spanning a wide date range — retried a few
  # times with backoff before we give up and let the caller see the error.
  RETRYABLE_CODES = [ 429, 500, 502, 503, 504 ].freeze
  MAX_ATTEMPTS = 4
  RETRY_BACKOFF_SECONDS = 2

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

    response = with_retries { HTTParty.get(CDX_BASE_URL, query: query, timeout: 60) }
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

    response = with_retries do
      temp_file.rewind
      temp_file.truncate(0)
      HTTParty.get(archive_url, stream_body: true, timeout: 120) do |fragment|
        temp_file.write(fragment)
      end
    end
    temp_file.close

    unless response.code == 200
      temp_file.unlink
      raise "Failed to fetch Wayback snapshot #{archive_url} (HTTP #{response.code})"
    end

    temp_file.path
  end

  def self.with_retries
    attempts = 0
    response = nil

    loop do
      attempts += 1
      response = yield
      break unless RETRYABLE_CODES.include?(response.code)
      break if attempts >= MAX_ATTEMPTS

      sleep(RETRY_BACKOFF_SECONDS * attempts) unless Rails.env.test?
    end

    response
  end
  private_class_method :with_retries
end
