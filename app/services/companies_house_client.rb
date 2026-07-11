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

  # Fetch detailed company profile by company number.
  # Uses GET /company/{company_number} endpoint.
  # Returns a hash with :company_status, :company_type, :date_of_creation, :sic_codes
  # or nil on failure.
  def self.fetch_profile(company_number)
    return nil if company_number.blank?

    api_key = self.api_key
    if api_key.blank?
      Rails.logger.warn("Companies House API key is missing. Skipping profile fetch for: #{company_number}")
      return nil
    end

    # Zero-pad company number to 8 characters
    padded_number = company_number.to_s.rjust(8, "0")
    uri = URI("#{base_url}/company/#{padded_number}")

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = true
    http.read_timeout = 5
    http.open_timeout = 3

    Rails.logger.info("Fetching Companies House profile for: #{padded_number} (Base URL: #{base_url})")

    request = Net::HTTP::Get.new(uri.request_uri)
    request.basic_auth(api_key, "")

    response = http.request(request)

    if response.code == "200"
      data = JSON.parse(response.body)
      sic_codes = data["sic_codes"] || []

      Rails.logger.info("Companies House profile fetched for: #{padded_number} -> status=#{data['company_status']}, type=#{data['type']}")
      {
        company_status: data["company_status"],
        company_type: data["type"],
        date_of_creation: data["date_of_creation"],
        sic_codes: sic_codes
      }
    elsif response.code == "404"
      Rails.logger.warn("Companies House profile not found (404) for: #{padded_number}")
      nil
    elsif response.code == "429"
      Rails.logger.error("Companies House API Rate Limit exceeded (429) for profile: #{padded_number}")
      nil
    else
      Rails.logger.error("Companies House API profile returned error #{response.code} for: #{padded_number}. Body: #{response.body}")
      nil
    end
  rescue Timeout::Error, Errno::EINVAL, Errno::ECONNRESET, Errno::ECONNREFUSED, Net::HTTPBadResponse, Net::HTTPHeaderSyntaxError, Net::ProtocolError => e
    Rails.logger.error("Companies House API profile connection failed for: #{company_number} - #{e.class}: #{e.message}")
    nil
  end
end
