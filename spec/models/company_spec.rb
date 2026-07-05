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
  end

  describe "instance helpers" do
    let(:company) { build(:company, name: "Acme Ltd", town: "London", county: "Greater London") }

    describe "#city_slug" do
      it "returns normalised town" do
        expect(company.city_slug).to eq("london")
      end
    end

    describe "#seo_summary" do
      it "generates an informative summary for active sponsors" do
        company.save!
        create(:sponsor_licence, company: company, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.utc(2026, 6, 1))
        expect(company.seo_summary).to include("Acme Ltd is an A-rated UK visa sponsor based in London, Greater London")
        expect(company.seo_summary).to include("licensed to sponsor workers on the Skilled Worker route")
        expect(company.seo_summary).to include("last verified against the GOV.UK register in June 2026")
      end

      it "generates a summary for removed sponsors" do
        company.save!
        expect(company.seo_summary).to eq("Acme Ltd was previously listed on the UK visa sponsor register but has since been removed.")
      end
    end
  end
end
