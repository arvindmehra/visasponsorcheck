require "rails_helper"

RSpec.describe "Companies", type: :request do
  describe "GET /companies/:id" do
    let!(:company) { create(:company, name: "BOLTWHIZ LIMITED") }
    let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker") }
    let!(:import_log) { create(:sponsor_import_log) }
    let!(:change_event) { create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "added") }

    it "finds the company by slug and displays details" do
      get company_path(company)
      expect(response).to have_http_status(:success)
      expect(response.body).to include("BOLTWHIZ LIMITED")
      expect(response.body).to include("Skilled Worker")
      expect(response.body).to include("Added as a licensed sponsor")
    end
  end
end
