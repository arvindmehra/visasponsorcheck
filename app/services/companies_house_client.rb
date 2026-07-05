require "net/http"
require "uri"
require "json"

class CompaniesHouseClient
  LIVE_URL = "https://api.company-information.service.gov.uk".freeze
  SANDBOX_URL = "https://api-sandbox.company-information.service.gov.uk".freeze

  def self.base_url
    if ENV["COMPANIES_HOUSE_SANDBOX"] == "true"
      SANDBOX_URL
    else
      LIVE_URL
    end
  end

  def self.api_key
    if ENV["COMPANIES_HOUSE_SANDBOX"] == "true"
      ENV["COMPANIES_HOUSE_DEV_API_KEY"].presence ||
        Rails.application.credentials.dig(:companies_house, :dev_api_key) ||
        ENV["COMPANIES_HOUSE_API_KEY"].presence ||
        Rails.application.credentials.dig(:companies_house, :api_key)
    else
      ENV["COMPANIES_HOUSE_API_KEY"].presence ||
        Rails.application.credentials.dig(:companies_house, :api_key)
    end
  end

  def self.search_by_name(name)
    # Sandbox/Test stub bypass to test end-to-end sandbox flow locally
    if ENV["COMPANIES_HOUSE_SANDBOX"] == "true" && name.strip.upcase == "COMPANY 68703880 LIMITED"
      Rails.logger.info("Companies House Sandbox bypass hit for: #{name}")
      return {
        company_number: "68703880",
        address: "House Name, Companies House, Crownway, Cardiff, United Kingdom, CF14 3UZ"
      }
    end

    api_key = self.api_key
    if api_key.blank?
      Rails.logger.warn("Companies House API key is missing. Skipping lookup for: #{name}")
      return nil
    end

    escaped_name = CGI.escape(name.strip)
    uri = URI("#{base_url}/search/companies?q=#{escaped_name}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 5 # seconds
    http.open_timeout = 3 # seconds

    Rails.logger.info("Querying Companies House API for: #{name} (Base URL: #{base_url})")

    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(api_key, "")

    response = http.request(request)

    if response.code == "200"
      data = JSON.parse(response.body)
      items = data["items"] || []

      # Grab the first match that is active, or fallback to first result
      best_match = items.find { |i| i["company_status"] == "active" } || items.first

      if best_match
        Rails.logger.info("Companies House API success for: #{name} -> Found Company Number: #{best_match['company_number']}")
        {
          company_number: best_match["company_number"],
          address: best_match["address_snippet"]
        }
      else
        Rails.logger.info("Companies House API success for: #{name} -> No matches found")
        nil
      end
    elsif response.code == "429"
      Rails.logger.error("Companies House API Rate Limit exceeded (429) for: #{name}")
      nil
    else
      Rails.logger.error("Companies House API returned error #{response.code} for: #{name}. Body: #{response.body}")
      nil
    end
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    Rails.logger.error("Companies House API connection failed for: #{name} - #{e.class}: #{e.message}")
    nil
  end
end
