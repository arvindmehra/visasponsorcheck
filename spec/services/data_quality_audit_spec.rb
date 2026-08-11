require "rails_helper"

RSpec.describe DataQualityAudit do
  describe ".run" do
    let(:company) { create(:company, name: "Test Company", town: "London") }

    it "runs cleanly when there are no anomalies" do
      create(:sponsor_licence, company: company, status: "active", route: "Skilled Worker")
      warnings = DataQualityAudit.run
      expect(warnings).to be_empty
    end

    it "detects companies with missing normalised town slugs" do
      create(:sponsor_licence, company: company, status: "active", route: "Skilled Worker")
      # bypass setter to force a null/empty town_normalised
      company.update_columns(town_normalised: nil)

      warnings = DataQualityAudit.run
      expect(warnings.join).to include("missing normalised town slugs")
    end

    it "detects spelling drift / non-canonical town names" do
      bad_company = create(:company, name: "Bad Town Ltd", town: "London")
      create(:sponsor_licence, company: bad_company, status: "active", route: "Skilled Worker")
      # bypass setter to force spelling drift
      bad_company.update_columns(town: "Abbeywood", town_normalised: "abbeywood")

      warnings = DataQualityAudit.run
      expect(warnings.join).to include("non-canonical town names")
    end

    it "detects sudden drops/spikes in total count" do
      create(:sponsor_import_log, status: "done", total_rows: 100)
      create(:sponsor_import_log, status: "done", total_rows: 130) # 30% spike

      warnings = DataQualityAudit.run
      expect(warnings.join).to include("Sponsor count changed drastically")
    end
  end
end
