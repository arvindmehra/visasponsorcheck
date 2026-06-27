require "httparty"
require "nokogiri"
require "tempfile"
require "uri"

class SponsorCsvDownloader
  GOV_UK_URL = "https://www.gov.uk/government/publications/register-of-licensed-sponsors-workers".freeze

  def self.call(source = nil)
    new(source).download
  end

  def initialize(source = nil)
    @source = source || GOV_UK_URL
  end

  def download
    if local_file?(@source)
      return { path: @source, url: @source, filename: File.basename(@source) }
    end

    url = if @source == GOV_UK_URL
            scrape_csv_url
          else
            @source
          end

    raise "Could not resolve CSV URL" if url.blank?

    # Download URL to a temp file
    temp_file = Tempfile.new(["sponsor_register", ".csv"])
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
    response = HTTParty.get(GOV_UK_URL)
    return nil unless response.code == 200

    doc = Nokogiri::HTML(response.body)
    # Look for links ending in .csv
    csv_links = doc.css("a").map { |a| a["href"] }.compact.select { |href| href.end_with?(".csv") }

    # Try to find one containing worker/temporary worker
    target_link = csv_links.find { |href| href.include?("Worker") } || csv_links.first

    return nil unless target_link

    # Make absolute if relative
    if target_link.start_with?("/")
      "https://www.gov.uk#{target_link}"
    else
      target_link
    end
  end
end
