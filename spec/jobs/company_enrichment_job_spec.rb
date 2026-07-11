require "rails_helper"

RSpec.describe CompanyEnrichmentJob, type: :job do
  describe "#perform" do
    let(:company) { create(:company) }

    it "enriches the company and its profile, then sleeps to pace API usage" do
      expect(CompanyEnricher).to receive(:enrich!).with(company)
      expect(CompanyProfileEnricher).to receive(:enrich!).with(company)
      expect_any_instance_of(CompanyEnrichmentJob).to receive(:sleep).with(0.5)

      described_class.perform_now(company.id)
    end

    it "does nothing when the company no longer exists" do
      expect(CompanyEnricher).not_to receive(:enrich!)
      expect(CompanyProfileEnricher).not_to receive(:enrich!)

      described_class.perform_now(-1)
    end
  end

  it "limits concurrency to a single running job to respect the Companies House rate limit" do
    expect(described_class.concurrency_limit).to eq(1)
  end
end
