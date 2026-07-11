require "rails_helper"

RSpec.describe CompanyProfileEnricher do
  describe ".enrich!" do
    let(:company) { create(:company, company_number: "03900676") }

    context "when company has no company_number" do
      let(:company) { create(:company, company_number: nil) }

      it "does not call the client and returns the company unchanged" do
        expect(CompaniesHouseClient).not_to receive(:fetch_profile)

        result = described_class.enrich!(company)
        expect(result).to eq(company)
        expect(company.company_profile).to be_nil
      end
    end

    context "when already enriched" do
      before do
        company.create_company_profile!(enriched_at: 1.day.ago)
      end

      it "does not call the client again" do
        expect(CompaniesHouseClient).not_to receive(:fetch_profile)

        described_class.enrich!(company)
      end
    end

    context "when the client returns profile data" do
      before do
        allow(CompaniesHouseClient).to receive(:fetch_profile).with("03900676").and_return({
          company_status: "active",
          company_type: "ltd",
          date_of_creation: "2016-07-26",
          sic_codes: [ "62090", "62020" ]
        })
      end

      it "creates the profile with the primary SIC code and description" do
        described_class.enrich!(company)

        profile = company.reload.company_profile
        expect(profile.company_status).to eq("active")
        expect(profile.company_type).to eq("ltd")
        expect(profile.date_of_creation).to eq(Date.new(2016, 7, 26))
        expect(profile.sic_code).to eq(62090)
        expect(profile.sic_code_description).to eq("Other information technology service activities")
        expect(profile.enriched_at).to be_present
      end
    end

    context "when the client returns nil" do
      before do
        allow(CompaniesHouseClient).to receive(:fetch_profile).with("03900676").and_return(nil)
      end

      it "marks the profile as enriched without setting profile fields" do
        described_class.enrich!(company)

        profile = company.reload.company_profile
        expect(profile.enriched_at).to be_present
        expect(profile.company_status).to be_nil
      end
    end

    context "when an error is raised" do
      before do
        allow(CompaniesHouseClient).to receive(:fetch_profile).and_raise(StandardError.new("boom"))
      end

      it "rescues the error and returns the company" do
        expect(Rails.logger).to receive(:error).with(/Profile enrichment failed/)

        result = described_class.enrich!(company)
        expect(result).to eq(company)
      end
    end

    context "when Companies House is rate limiting" do
      before do
        allow(CompaniesHouseClient).to receive(:fetch_profile).and_raise(CompaniesHouseClient::RateLimitError)
      end

      it "propagates the RateLimitError instead of marking the profile enriched" do
        expect { described_class.enrich!(company) }.to raise_error(CompaniesHouseClient::RateLimitError)
        expect(company.reload.company_profile).to be_nil
      end
    end
  end
end
