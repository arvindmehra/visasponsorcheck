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
      expect(response.body).to include("A-rated")
    end
  end

  describe "GET /companies/:id (legacy route)" do
    it "redirects to the new /sponsor/:id route with a 301" do
      get "/companies/#{company.slug}"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to(company_path(company))
    end
  end

  describe "GET /sponsor/:id/enrich" do
    context "when company has not been enriched" do
      it "calls CompanyEnricher and returns the HTML partial" do
        expect(CompanyEnricher).to receive(:enrich!).and_wrap_original do |method, company|
          company.update!(company_number: "03900676", registered_office_address: "123 Street")
          company
        end

        get enrich_company_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Company Details")
        expect(response.body).to include("03900676")
        expect(response.body).to include("123 Street")
      end

      it "returns the external resources partial when card: external is requested" do
        expect(CompanyEnricher).to receive(:enrich!).and_wrap_original do |method, company|
          company.update!(company_number: "03900676", registered_office_address: "123 Street")
          company
        end

        get enrich_company_path(company, card: :external)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("External Resources")
        expect(response.body).to include("Companies House")
        expect(response.body).not_to include("Company Details")
      end
    end

    context "when company is already enriched" do
      before do
        company.update!(company_number: "99999999", registered_office_address: "Already Rich Road", enriched_at: Time.current)
      end

      it "does not call CompanyEnricher and returns cached info" do
        expect(CompanyEnricher).not_to receive(:enrich!)

        get enrich_company_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("99999999")
        expect(response.body).to include("Already Rich Road")
      end

      it "does not call CompanyEnricher and returns cached external resources info" do
        expect(CompanyEnricher).not_to receive(:enrich!)

        get enrich_company_path(company, card: :external)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("External Resources")
        expect(response.body).to include("Companies House")
      end
    end
  end
end
