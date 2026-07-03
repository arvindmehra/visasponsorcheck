require "rails_helper"

RSpec.describe "Companies", type: :request do
  let!(:company) { create(:company, name: "BOLTWHIZ LIMITED") }
  let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker") }
  let!(:import_log) { create(:sponsor_import_log) }
  let!(:change_event) { create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "added") }

  describe "GET /sponsor/:id" do
    it "finds the company by slug and displays details" do
      get company_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BOLTWHIZ LIMITED")
      expect(response.body).to include("Skilled Worker")
      expect(response.body).to include("is an A-rated UK visa sponsor")
    end
  end

  describe "GET /companies/:id (legacy route)" do
    it "redirects to the new /sponsor/:id route with a 301" do
      get "/companies/#{company.slug}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(company_path(company))
    end
  end
end

