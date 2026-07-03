require "rails_helper"

RSpec.describe CompanyEnricher do
  describe ".enrich!" do
    let(:company) { Company.create!(name: "Test Company Ltd", slug: "test-company-ltd", name_normalised: "test company ltd") }

    context "when company has already been enriched" do
      before do
        company.update!(company_number: "12345678", registered_office_address: "123 Test St", enriched_at: Time.current)
      end

      it "does not query Companies House API and returns the company" do
        expect(CompaniesHouseClient).not_to receive(:search_by_name)
        result = described_class.enrich!(company)
        expect(result).to eq(company)
      end
    end

    context "when company is not enriched yet" do
      context "and Companies House returns a match" do
        it "updates the company's enrichment details and sets enriched_at" do
          expect(CompaniesHouseClient).to receive(:search_by_name).with(company.name).and_return({
            company_number: "87654321",
            address: "456 Main St"
          })

          result = described_class.enrich!(company)
          expect(result.company_number).to eq("87654321")
          expect(result.registered_office_address).to eq("456 Main St")
          expect(result.enriched_at).to be_present
        end
      end

      context "and Companies House returns nil" do
        it "leaves company details empty but still sets enriched_at to avoid re-querying" do
          expect(CompaniesHouseClient).to receive(:search_by_name).with(company.name).and_return(nil)

          result = described_class.enrich!(company)
          expect(result.company_number).to be_nil
          expect(result.registered_office_address).to be_nil
          expect(result.enriched_at).to be_present
        end
      end

      context "and an error is raised during lookup" do
        it "rescues error and returns the company" do
          expect(CompaniesHouseClient).to receive(:search_by_name).and_raise("API error")
          expect(Rails.logger).to receive(:error).with(/Enrichment failed/)

          result = described_class.enrich!(company)
          expect(result).to eq(company)
        end
      end
    end
  end
end
