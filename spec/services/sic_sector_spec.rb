require "rails_helper"

RSpec.describe SicSector do
  describe ".for_sic_code" do
    it "maps a 5-digit code to its sector via the derived 2-digit division" do
      expect(described_class.for_sic_code("62090")).to eq("information-communication")
      expect(described_class.for_sic_code(45111)).to eq("motor-vehicle-trade")
      expect(described_class.for_sic_code("46350")).to eq("wholesale-trade")
      expect(described_class.for_sic_code("47110")).to eq("retail-trade")
      expect(described_class.for_sic_code("10612")).to eq("manufacturing")
    end

    it "correctly handles codes whose division starts with a leading zero" do
      # "01110" stored as an integer loses the leading zero, but division
      # extraction (code / 1000) still recovers division 1 correctly.
      expect(described_class.for_sic_code(1110)).to eq("agriculture-forestry-fishing")
    end
  end

  describe ".name_for" do
    it "returns the friendly name for a known key" do
      expect(described_class.name_for("manufacturing")).to eq("Manufacturing")
    end

    it "returns nil for an unknown key" do
      expect(described_class.name_for("not-a-sector")).to be_nil
    end
  end

  describe ".division_range" do
    it "returns the division range for a known key" do
      expect(described_class.division_range("wholesale-trade")).to eq(46..46)
      expect(described_class.division_range("manufacturing")).to eq(10..33)
    end

    it "returns nil for an unknown key" do
      expect(described_class.division_range("not-a-sector")).to be_nil
    end
  end

  it "covers every SIC division present in SicCodeLookup exactly once" do
    all_divisions = SicCodeLookup::DESCRIPTIONS.keys.map { |code| code.to_i / 1000 }.uniq

    all_divisions.each do |division|
      matches = described_class::GROUPS.select { |_, group| group[:divisions].cover?(division) }
      expect(matches.size).to eq(1), "expected division #{division} to be covered exactly once, got #{matches.keys}"
    end
  end

  describe ".active_company_counts" do
    it "counts distinct active companies per sector without double-counting multiple licences" do
      company = create(:company)
      company.create_company_profile!(sic_code: 62012, enriched_at: Time.current)
      create(:sponsor_licence, company: company, status: "active", route: "Skilled Worker")
      create(:sponsor_licence, company: company, status: "active", route: "Health and Care Worker")

      other_company = create(:company)
      other_company.create_company_profile!(sic_code: 46350, enriched_at: Time.current)
      create(:sponsor_licence, company: other_company, status: "active", route: "Skilled Worker")

      # A company with no active licence should not be counted
      inactive_company = create(:company)
      inactive_company.create_company_profile!(sic_code: 62090, enriched_at: Time.current)
      create(:sponsor_licence, company: inactive_company, status: "removed", route: "Skilled Worker")

      counts = described_class.active_company_counts
      expect(counts["information-communication"]).to eq(1)
      expect(counts["wholesale-trade"]).to eq(1)
      expect(counts["manufacturing"]).to eq(0)
    end
  end

  describe ".ranked" do
    it "sorts sectors by company count descending" do
      company_a = create(:company)
      company_a.create_company_profile!(sic_code: 46350, enriched_at: Time.current)
      create(:sponsor_licence, company: company_a, status: "active", route: "Skilled Worker")

      company_b = create(:company)
      company_b.create_company_profile!(sic_code: 46360, enriched_at: Time.current)
      create(:sponsor_licence, company: company_b, status: "active", route: "Skilled Worker")

      company_c = create(:company)
      company_c.create_company_profile!(sic_code: 62012, enriched_at: Time.current)
      create(:sponsor_licence, company: company_c, status: "active", route: "Skilled Worker")

      ranked = described_class.ranked
      wholesale_index = ranked.index { |s| s[:key] == "wholesale-trade" }
      it_index = ranked.index { |s| s[:key] == "information-communication" }

      expect(ranked.first[:key]).to eq("wholesale-trade")
      expect(wholesale_index).to be < it_index
    end

    it "excludes zero-count sectors when only_populated is true" do
      company = create(:company)
      company.create_company_profile!(sic_code: 46350, enriched_at: Time.current)
      create(:sponsor_licence, company: company, status: "active", route: "Skilled Worker")

      ranked = described_class.ranked(only_populated: true)
      expect(ranked.map { |s| s[:key] }).to eq([ "wholesale-trade" ])
    end

    it "respects the limit" do
      expect(described_class.ranked(limit: 3).size).to eq(3)
    end
  end
end
