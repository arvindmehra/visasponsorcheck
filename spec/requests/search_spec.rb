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

    it "handles typeahead frame requests" do
      get search_path, params: { q: "Boltwhiz" }, headers: { "Turbo-Frame" => "typeahead_results" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Suggestions")
      expect(response.body).to include("BOLTWHIZ LIMITED")
      expect(response.body).not_to include("VisaSponsorCheck")
    end

    it "returns empty state if no matches" do
      get search_path, params: { q: "Nonexistent" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("No results found")
    end

    it "logs a completed search with its query and results count" do
      expect {
        get search_path, params: { q: "Boltwhiz" }
      }.to change(SearchLog, :count).by(1)

      log = SearchLog.last
      expect(log.query).to eq("boltwhiz")
      expect(log.results_count).to eq(1)
    end

    it "logs a zero-result search" do
      expect {
        get search_path, params: { q: "Nonexistent" }
      }.to change(SearchLog, :count).by(1)

      expect(SearchLog.last.results_count).to eq(0)
    end

    it "does not log typeahead keystroke requests" do
      expect {
        get search_path, params: { q: "Boltwhiz" }, headers: { "Turbo-Frame" => "typeahead_results" }
      }.not_to change(SearchLog, :count)
    end

    it "does not log a blank query" do
      expect {
        get search_path, params: { q: "" }
      }.not_to change(SearchLog, :count)
    end

    it "does not fail the search if logging errors out" do
      allow(SearchLog).to receive(:create!).and_raise(StandardError.new("boom"))
      expect(Rails.logger).to receive(:error).with(/Failed to log search/)

      get search_path, params: { q: "Boltwhiz" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BOLTWHIZ LIMITED")
    end
  end
end
