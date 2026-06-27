require "rails_helper"

RSpec.describe "Searches", type: :request do
  describe "GET /search" do
    let!(:company) { create(:company, name: "BOLTWHIZ LIMITED") }
    let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker") }

    it "returns results for matching query" do
      get search_path, params: { q: "Boltwhiz" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BOLTWHIZ LIMITED")
    end

    it "handles turbo frame requests without layout" do
      get search_path, params: { q: "Boltwhiz" }, headers: { "Turbo-Frame" => "search_results" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BOLTWHIZ LIMITED")
      expect(response.body).not_to include("VisaSponsorCheck") # Header text from main layout
    end

    it "returns empty state if no matches" do
      get search_path, params: { q: "Nonexistent" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("No results found")
    end
  end
end
