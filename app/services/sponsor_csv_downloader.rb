require "httparty"
require "tempfile"
require "uri"

class SponsorCsvDownloader
  GOV_UK_CONTENT_API_URL = "https://www.gov.uk/api/content/government/publications/register-of-licensed-sponsors-workers".freeze

  def self.call(source = nil)
    new(source).download
  end

  def initialize(source = nil)
    @source = source
  end

  def download
    if @source && local_file?(@source)
      return { path: @source, url: @source, filename: File.basename(@source) }
    end

    url = @source || scrape_csv_url

    raise "Could not resolve CSV URL" if url.blank?

    # Download URL to a temp file
    temp_file = Tempfile.new([ "sponsor_register", ".csv" ])
    temp_file.binmode

    response = HTTParty.get(url, stream_body: true) do |fragment|
      temp_file.write(fragment)
    end

    if response.code != 200
      temp_file.close
      temp_file.unlink
      raise "Failed to download CSV from #{url} (HTTP #{response.code})"
    end

    temp_file.close

    {
      path: temp_file.path,
      url: url,
      filename: File.basename(URI.parse(url).path)
    }
  end

  private

  def local_file?(source)
    source.present? && File.exist?(source)
  end

  def scrape_csv_url
    response = HTTParty.get(GOV_UK_CONTENT_API_URL, headers: cache_busting_headers, timeout: 30)
    raise "GOV.UK Content API returned HTTP #{response.code}" unless response.code == 200

    data = JSON.parse(response.body)
    attachments = data.dig("details", "attachments") || []

    # Find the Worker register CSV attachment
    attachment = attachments.find { |a| a["content_type"] == "text/csv" && a["filename"]&.include?("Worker") }
    attachment ||= attachments.find { |a| a["content_type"] == "text/csv" }

    attachment&.fetch("url", nil)
  end

  def cache_busting_headers
    {
      "Cache-Control" => "no-cache, no-store, must-revalidate",
      "Pragma" => "no-cache",
      "User-Agent" => "VisaSponsorCheck/1.0 (+https://visasponsorcheck.co.uk)"
    }
  end
end
