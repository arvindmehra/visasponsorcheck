require "rails_helper"

RSpec.describe Company, type: :model do
  describe "validations" do
    subject { build(:company) }

    it { is_expected.to validate_presence_of(:name) }

    # name_normalised is auto-computed from name via callback — test the DB constraint directly
    it "requires name_normalised at the DB level" do
      company = create(:company)
      expect {
        company.class.connection.execute(
          "UPDATE companies SET name_normalised = NULL WHERE id = #{company.id}"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /null value.*name_normalised/)
    end

    # FriendlyId generates slugs automatically, so we test the DB unique constraint directly
    it "enforces unique slugs at the database level" do
      company = create(:company)
      expect {
        Company.connection.execute(
          "INSERT INTO companies (name, name_normalised, slug, created_at, updated_at) " \
          "VALUES ('Other Co', 'other co', #{Company.connection.quote(company.slug)}, NOW(), NOW())"
        )
      }.to raise_error(ActiveRecord::StatementInvalid, /unique.*slug|slug.*unique/i)
    end
  end

  describe "associations" do
    it { is_expected.to have_many(:sponsor_licences).dependent(:destroy) }
    it { is_expected.to have_many(:sponsor_change_events).dependent(:destroy) }
  end

  describe "callbacks" do
    describe "#normalise_name" do
      it "strips leading and trailing whitespace" do
        company = build(:company, name: "  Acme Ltd  ")
        company.valid?
        expect(company.name).to eq("Acme Ltd")
      end

      it "collapses internal whitespace" do
        company = build(:company, name: "Acme   Corp   Ltd")
        company.valid?
        expect(company.name).to eq("Acme Corp Ltd")
      end

      it "sets name_normalised to downcased name" do
        company = build(:company, name: "Acme Ltd")
        company.valid?
        expect(company.name_normalised).to eq("acme ltd")
      end

      it "handles names with all-caps" do
        company = build(:company, name: " BOLTWHIZ LIMITED")
        company.valid?
        expect(company.name).to eq("BOLTWHIZ LIMITED")
        expect(company.name_normalised).to eq("boltwhiz limited")
      end
    end
  end

  describe ".fuzzy_search" do
    before do
      create(:company, name: "Google UK Limited")
      create(:company, name: "Amazon Web Services UK")
      create(:company, name: "Microsoft Limited")
    end

    it "finds exact matches" do
      results = Company.fuzzy_search("Google UK Limited")
      expect(results.map(&:name)).to include("Google UK Limited")
    end

    it "finds partial matches" do
      results = Company.fuzzy_search("Google")
      expect(results.map(&:name)).to include("Google UK Limited")
    end

    it "finds fuzzy matches with typos" do
      results = Company.fuzzy_search("Gogle UK")
      expect(results.map(&:name)).to include("Google UK Limited")
    end

    it "returns none for blank query" do
      expect(Company.fuzzy_search("")).to be_empty
    end
  end

  describe "#active_sponsor?" do
    let(:company) { create(:company) }

    it "returns true when company has at least one active licence" do
      create(:sponsor_licence, company: company, status: "active")
      expect(company.active_sponsor?).to be true
    end

    it "returns false when all licences are removed" do
      create(:sponsor_licence, :removed, company: company)
      expect(company.active_sponsor?).to be false
    end

    it "returns false when company has no licences" do
      expect(company.active_sponsor?).to be false
    end
  end

  describe "#routes" do
    let(:company) { create(:company) }

    it "returns sorted unique active routes" do
      create(:sponsor_licence, company: company, route: "Skilled Worker", status: "active")
      create(:sponsor_licence, company: company, route: "Intra-Company Transfer", status: "active")
      create(:sponsor_licence, company: company, route: "Seasonal Worker", status: "removed")
      expect(company.routes).to eq([ "Intra-Company Transfer", "Skilled Worker" ])
    end
  end

  describe "location sanitisation" do
    it "converts literal NULL string in town to nil" do
      company = build(:company, town: "NULL")
      expect(company.town).to be_nil
    end

    it "converts literal NULL string in county to nil (case insensitive)" do
      company = build(:company, county: "null")
      expect(company.county).to be_nil
    end

    it "strips whitespace from town" do
      company = build(:company, town: "  Norfolk  ")
      expect(company.town).to eq("Norfolk")
    end

    it "converts empty string town to nil" do
      company = build(:company, town: "")
      expect(company.town).to be_nil
    end
  end

  describe "#location" do
    it "returns town and county joined when both present" do
      company = build(:company, town: "Dunfermline", county: "Scotland")
      expect(company.location).to eq("Dunfermline, Scotland")
    end

    it "returns town only when county is nil" do
      company = build(:company, town: "London", county: nil)
      expect(company.location).to eq("London")
    end

    it "returns nil when both town and county are absent" do
      company = build(:company, town: nil, county: nil)
      expect(company.location).to be_nil
    end
  end

  describe "town_normalised and slugging" do
    it "sets town_normalised when town is assigned" do
      company = build(:company, town: "  London  ")
      expect(company.town_normalised).to eq("london")
    end

    it "sets town_normalised to nil when town is nil" do
      company = build(:company, town: nil)
      expect(company.town_normalised).to be_nil
    end
  end

  describe "directory scopes" do
    let!(:london_company) { create(:company, town: "London") }
    let!(:manchester_company) { create(:company, town: "Manchester") }
    let!(:no_city_company) { create(:company, town: nil) }

    before do
      create(:sponsor_licence, company: london_company, status: "active", rating: "A", route: "Skilled Worker")
      create(:sponsor_licence, company: manchester_company, status: "active", rating: "B", route: "Temporary Worker")
      # removed licence only
      create(:sponsor_licence, company: no_city_company, status: "removed", rating: "A", route: "Skilled Worker")
    end

    describe ".by_city" do
      it "returns companies active in that city" do
        expect(Company.by_city("london")).to include(london_company)
        expect(Company.by_city("london")).not_to include(manchester_company)
      end
    end

    describe ".by_route" do
      it "returns companies active in that route" do
        expect(Company.by_route("Skilled Worker")).to include(london_company)
        expect(Company.by_route("Skilled Worker")).not_to include(manchester_company)
      end
    end

    describe ".a_rated" do
      it "returns active A-rated companies" do
        expect(Company.a_rated).to include(london_company)
        expect(Company.a_rated).not_to include(manchester_company)
      end
    end

    describe ".revoked" do
      it "returns companies with only removed licences" do
        expect(Company.revoked).to include(no_city_company)
        expect(Company.revoked).not_to include(london_company)
      end
    end

    describe ".distinct_cities" do
      it "returns distinct clean normalised cities sorted" do
        expect(Company.distinct_cities).to eq([ "london", "manchester" ])
      end
    end

    describe ".top_cities" do
      it "returns the top cities by company record count in descending order" do
        # Existing setup in this describe block has london_company and manchester_company (1 each)
        # Let's create more companies
        create(:company, town: "London") # London now has 2
        create(:company, town: "Birmingham") # Birmingham has 1
        create(:company, town: "Manchester") # Manchester now has 2
        create_list(:company, 2, town: "London") # London now has 4

        # Expected counts: London (4), Manchester (2), Birmingham (1)
        expect(Company.top_cities(2)).to eq([ "london", "manchester" ])
        expect(Company.top_cities(3)).to eq([ "london", "manchester", "birmingham" ])
      end
    end

    describe ".distinct_routes" do
      it "returns active routes sorted" do
        expect(Company.distinct_routes).to eq([ "Skilled Worker", "Temporary Worker" ])
      end
    end

    describe ".top_routes" do
      it "returns the top routes by distinct active-company count, descending" do
        # Existing setup: london_company has 1 Skilled Worker licence, manchester_company has 1 Temporary Worker licence
        extra_company = create(:company, town: "Bristol")
        create(:sponsor_licence, company: extra_company, status: "active", rating: "A", route: "Skilled Worker")

        # Skilled Worker (2 companies) should outrank Temporary Worker (1 company)
        expect(Company.top_routes(1)).to eq([ "Skilled Worker" ])
        expect(Company.top_routes(2)).to eq([ "Skilled Worker", "Temporary Worker" ])
      end

      it "does not double-count a company with multiple licences for the same route family" do
        create(:sponsor_licence, company: london_company, status: "active", rating: "B", route: "Health and Care Worker")

        expect(Company.top_routes(3)).to include("Skilled Worker", "Temporary Worker", "Health and Care Worker")
      end
    end

    describe ".by_sector" do
      before do
        london_company.create_company_profile!(sic_code: 62012, enriched_at: Time.current) # information-communication
        manchester_company.create_company_profile!(sic_code: 46350, enriched_at: Time.current) # wholesale-trade
      end

      it "returns companies whose SIC code falls in the sector's division range" do
        expect(Company.by_sector("information-communication")).to include(london_company)
        expect(Company.by_sector("information-communication")).not_to include(manchester_company)

        expect(Company.by_sector("wholesale-trade")).to include(manchester_company)
        expect(Company.by_sector("wholesale-trade")).not_to include(london_company)
      end

      it "returns none for an unknown sector key" do
        expect(Company.by_sector("not-a-real-sector")).to be_empty
      end

      it "does not double-count a company with multiple active licences" do
        create(:sponsor_licence, company: london_company, status: "active", rating: "A", route: "Health and Care Worker")

        expect(Company.by_sector("information-communication").count).to eq(1)
      end
    end
  end

  describe "instance helpers" do
    let(:company) { build(:company, name: "Acme Ltd", town: "London", county: "Greater London") }

    describe "#city_slug" do
      it "returns normalised town" do
        expect(company.city_slug).to eq("london")
      end
    end
  end

  describe ".related_to" do
    let!(:target) { create(:company, name: "Target Ltd", town: "London") }
    let!(:target_licence) { create(:sponsor_licence, company: target, route: "Skilled Worker", status: "active") }

    let!(:same_city) { create(:company, name: "Same City Ltd", town: "London") }
    let!(:same_city_licence) { create(:sponsor_licence, company: same_city, route: "Temporary Worker", status: "active") }

    let!(:same_route) { create(:company, name: "Same Route Ltd", town: "Leeds") }
    let!(:same_route_licence) { create(:sponsor_licence, company: same_route, route: "Skilled Worker", status: "active") }

    let!(:unrelated) { create(:company, name: "Unrelated Ltd", town: "Bristol") }
    let!(:unrelated_licence) { create(:sponsor_licence, company: unrelated, route: "Temporary Worker", status: "active") }

    it "includes companies in the same city and companies on the same visa route, excluding itself and unrelated companies" do
      related = Company.related_to(target, limit: 5)

      expect(related).to include(same_city, same_route)
      expect(related).not_to include(target, unrelated)
    end

    it "never returns more than the requested limit" do
      related = Company.related_to(target, limit: 1)
      expect(related.size).to eq(1)
    end

    it "does not duplicate a company that matches on both city and route" do
      create(:sponsor_licence, company: same_city, route: "Skilled Worker", status: "active")

      related = Company.related_to(target, limit: 5)
      expect(related.count { |c| c.id == same_city.id }).to eq(1)
    end
  end
end
