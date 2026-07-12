require "rails_helper"

RSpec.describe "Sponsors Directory", type: :request do
  let!(:london_company) { create(:company, name: "Alpha Ltd", town: "London") }
  let!(:leeds_company) { create(:company, name: "Beta Ltd", town: "Leeds") }

  let!(:licence1) { create(:sponsor_licence, company: london_company, route: "Skilled Worker", rating: "A", status: "active") }
  let!(:licence2) { create(:sponsor_licence, company: leeds_company, route: "Temporary Worker", rating: "B", status: "active") }

  describe "GET /sponsors" do
    it "renders the index page successfully" do
      get sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("UK Visa Sponsor Directory")
      expect(response.body).to include("Browse by City")
      expect(response.body).to include("London")
      expect(response.body).to include("Skilled Worker")
    end
  end

  describe "GET /sponsors/locations" do
    it "renders the locations directory page successfully with grouped lists" do
      get locations_sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Browse by Location")
      expect(response.body).to include("Jump to Letter")
      # London and Leeds should be formatted and grouped under their respective letter headers
      expect(response.body).to include("London")
      expect(response.body).to include("Leeds")
      expect(response.body).to include("id=\"letter-L\"")
    end
  end

  describe "GET /sponsors/routes" do
    it "renders the routes directory page successfully with grouped lists" do
      get visa_routes_sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Browse by Visa Route")
      expect(response.body).to include("Jump to Letter")
      # Skilled Worker and Temporary Worker should be formatted and grouped under their respective letter headers
      expect(response.body).to include("Skilled Worker")
      expect(response.body).to include("Temporary Worker")
      expect(response.body).to include("id=\"letter-S\"")
      expect(response.body).to include("id=\"letter-T\"")
    end
  end

  describe "GET /sponsors/city/:city" do
    context "when sponsors exist in the city" do
      it "renders the city page successfully" do
        get city_sponsors_path(city: "london")
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Visa Sponsors in London")
        expect(response.body).to include("Alpha Ltd")
      end
    end

    context "when no sponsors exist in the city" do
      it "returns a 404 not found status" do
        # town_normalised needs to match the slug, so "bristol" won't find anything
        get city_sponsors_path(city: "bristol")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /sponsors/route/:route" do
    context "when sponsors exist for the route" do
      it "renders the route page successfully" do
        get visa_route_sponsors_path(route: "skilled-worker")
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Skilled Worker Visa Sponsors UK")
        expect(response.body).to include("Alpha Ltd")
      end
    end

    context "when no sponsors exist for the route" do
      it "returns a 404 not found status" do
        get visa_route_sponsors_path(route: "non-existent-route")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /sponsors/sectors" do
    it "renders the sectors directory page successfully" do
      get sectors_sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Browse by Sector")
    end
  end

  describe "GET /sponsors/sector/:sector" do
    context "when sponsors exist in the sector" do
      before do
        london_company.create_company_profile!(sic_code: 62012, enriched_at: Time.current)
      end

      it "renders the sector page successfully" do
        get sector_sponsors_path(sector: "information-communication")
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Visa Sponsors")
        expect(response.body).to include("Alpha Ltd")
      end
    end

    context "when the sector key is unknown" do
      it "returns a 404 not found status" do
        get sector_sponsors_path(sector: "not-a-real-sector")
        expect(response).to have_http_status(:not_found)
      end
    end

    context "when the sector is known but has no matching companies" do
      it "returns a 404 not found status" do
        get sector_sponsors_path(sector: "mining-quarrying")
        expect(response).to have_http_status(:not_found)
      end
    end
  end

  describe "GET /sponsors/a-rated" do
    it "renders the A-rated list successfully" do
      get a_rated_sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("A-Rated UK Visa Sponsor List")
      expect(response.body).to include("Alpha Ltd")
      expect(response.body).not_to include("Beta Ltd") # Beta is B-rated
    end
  end

  describe "GET /sponsors/revoked" do
    let!(:revoked_company) { create(:company, name: "Revoked Corp", town: "Bristol") }
    let!(:licence3) { create(:sponsor_licence, company: revoked_company, route: "Skilled Worker", status: "removed") }

    it "renders the revoked list successfully" do
      get revoked_sponsors_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Revoked UK Sponsor Licence List")
      expect(response.body).to include("Revoked Corp")
      expect(response.body).not_to include("Alpha Ltd") # Alpha is active
    end
  end
end
