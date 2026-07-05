require "rails_helper"

RSpec.describe CompaniesHouseClient do
  describe ".search_by_name" do
    let(:company_name) { "Nvidia Ltd" }
    let(:api_key) { "test_api_key" }

    before do
      allow(Rails.application.credentials).to receive(:dig).with(:companies_house, :api_key).and_return(api_key)
      allow(Rails.application.credentials).to receive(:dig).with(:companies_house, :dev_api_key).and_return(nil)
    end

    context "when in sandbox mode" do
      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_SANDBOX').and_return('true')
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_DEV_API_KEY').and_return(nil)
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_API_KEY').and_return(nil)
      end

      it "uses dev_api_key from credentials if present" do
        allow(Rails.application.credentials).to receive(:dig).with(:companies_house, :dev_api_key).and_return("dev_key_from_creds")
        expect(described_class.api_key).to eq("dev_key_from_creds")
      end

      it "uses COMPANIES_HOUSE_DEV_API_KEY from env if present" do
        allow(Rails.application.credentials).to receive(:dig).with(:companies_house, :dev_api_key).and_return(nil)
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_DEV_API_KEY').and_return("dev_key_from_env")
        expect(described_class.api_key).to eq("dev_key_from_env")
      end

      it "falls back to production api_key if no dev key is specified" do
        allow(Rails.application.credentials).to receive(:dig).with(:companies_house, :dev_api_key).and_return(nil)
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_DEV_API_KEY').and_return(nil)
        expect(described_class.api_key).to eq(api_key)
      end
    end

    context "when API key is missing" do
      let(:api_key) { nil }

      before do
        allow(ENV).to receive(:[]).and_call_original
        allow(ENV).to receive(:[]).with('COMPANIES_HOUSE_API_KEY').and_return(nil)
      end

      it "returns nil and logs a warning" do
        expect(Rails.logger).to receive(:warn).with(/API key is missing/)
        expect(described_class.search_by_name(company_name)).to be_nil
      end
    end

    context "when Companies House returns 200 success" do
      let(:response_body) do
        {
          items: [
            {
              company_number: "03900676",
              company_status: "active",
              address_snippet: "8th Floor 20 Farringdon Street, London, EC4A 4AB",
              title: "NVIDIA LTD"
            }
          ]
        }.to_json
      end

      it "returns matched company details" do
        mock_response = double(code: "200", body: response_body)
        expect_any_instance_of(Net::HTTP).to receive(:request).and_return(mock_response)

        result = described_class.search_by_name(company_name)
        expect(result).to eq({
          company_number: "03900676",
          address: "8th Floor 20 Farringdon Street, London, EC4A 4AB"
        })
      end
    end

    context "when Companies House returns 429 rate limit" do
      it "returns nil and logs error" do
        mock_response = double(code: "429")
        expect_any_instance_of(Net::HTTP).to receive(:request).and_return(mock_response)
        expect(Rails.logger).to receive(:error).with(/Rate Limit exceeded/)

        expect(described_class.search_by_name(company_name)).to be_nil
      end
    end

    context "when connection timeout occurs" do
      it "handles the error gracefully and returns nil" do
        expect_any_instance_of(Net::HTTP).to receive(:request).and_raise(Timeout::Error.new("Timeout"))
        expect(Rails.logger).to receive(:error).with(/connection failed/)

        expect(described_class.search_by_name(company_name)).to be_nil
      end
    end
  end
end
