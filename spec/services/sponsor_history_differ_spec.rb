require "rails_helper"

RSpec.describe SponsorHistoryDiffer do
  describe ".call" do
    it "detects a company/route pair present in the newer snapshot but not the older one" do
      previous = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" } ]
      current = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" }, { organisation_name: "Beta Ltd", route: "Temporary Worker" } ]

      result = described_class.call(previous_rows: previous, current_rows: current)

      expect(result.added).to contain_exactly([ "beta ltd", "Temporary Worker" ])
      expect(result.removed).to be_empty
    end

    it "detects a company/route pair present in the older snapshot but not the newer one" do
      previous = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" }, { organisation_name: "Beta Ltd", route: "Temporary Worker" } ]
      current = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" } ]

      result = described_class.call(previous_rows: previous, current_rows: current)

      expect(result.removed).to contain_exactly([ "beta ltd", "Temporary Worker" ])
      expect(result.added).to be_empty
    end

    it "treats an unchanged company/route pair as neither added nor removed" do
      rows = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" } ]

      result = described_class.call(previous_rows: rows, current_rows: rows)

      expect(result.added).to be_empty
      expect(result.removed).to be_empty
    end

    it "is case-insensitive on company name" do
      previous = [ { organisation_name: "ALPHA LTD", route: "Skilled Worker" } ]
      current = [ { organisation_name: "alpha ltd", route: "Skilled Worker" } ]

      result = described_class.call(previous_rows: previous, current_rows: current)

      expect(result.added).to be_empty
      expect(result.removed).to be_empty
    end

    it "treats a route change on the same company as an add + a remove" do
      previous = [ { organisation_name: "Alpha Ltd", route: "Skilled Worker" } ]
      current = [ { organisation_name: "Alpha Ltd", route: "Temporary Worker" } ]

      result = described_class.call(previous_rows: previous, current_rows: current)

      expect(result.added).to contain_exactly([ "alpha ltd", "Temporary Worker" ])
      expect(result.removed).to contain_exactly([ "alpha ltd", "Skilled Worker" ])
    end

    it "skips rows with a blank organisation name or route" do
      previous = []
      current = [
        { organisation_name: "", route: "Skilled Worker" },
        { organisation_name: "Alpha Ltd", route: nil },
        { organisation_name: "Beta Ltd", route: "Skilled Worker" }
      ]

      result = described_class.call(previous_rows: previous, current_rows: current)

      expect(result.added).to contain_exactly([ "beta ltd", "Skilled Worker" ])
    end
  end
end
