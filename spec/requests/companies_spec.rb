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

    it "logs the visit to search_logs, keyed by the company's name" do
      expect {
        get company_path(company)
      }.to change(SearchLog, :count).by(1)

      log = SearchLog.last
      expect(log.query).to eq("boltwhiz limited")
      expect(log.results_count).to eq(1)
    end

    it "does not log the visit to search_logs when the request comes from a crawler/bot" do
      expect {
        get company_path(company), headers: { "HTTP_USER_AGENT" => "Mozilla/5.0 (compatible; Googlebot/2.1; +http://www.google.com/bot.html)" }
      }.not_to change(SearchLog, :count)
    end

    it "still renders the page even if logging the visit fails" do
      allow(SearchLog).to receive(:create!).and_raise(StandardError, "db down")

      get company_path(company)
      expect(response).to have_http_status(:success)
    end

    context "when the company has a profile" do
      before do
        company.update!(company_number: "03900676", enriched_at: Time.current)
        company.create_company_profile!(
          company_status: "active",
          company_type: "ltd",
          date_of_creation: Date.new(2016, 7, 26),
          sic_code: 62090,
          sic_code_description: "Other information technology service activities",
          enriched_at: Time.current
        )
      end

      it "displays the company profile fields in the details card" do
        get company_path(company)
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Active")
        expect(response.body).to include("Private Limited Company")
        expect(response.body).to include("26 July 2016")
        expect(response.body).to include("62090 - Other information technology service activities")
      end
    end
  end

  describe "GET /sponsor/:id — Licence History section" do
    it "shows granted and revoked events, labelled accordingly" do
      create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "removed", occurred_at: 1.day.ago)

      get company_path(company)

      expect(response.body).to include("Licence History")
      expect(response.body).to include("Licence granted")
      expect(response.body).to include("Licence revoked")
    end

    it "excludes rating/status/route/licence-type change events from the timeline" do
      create(:sponsor_change_event, company: company, sponsor_import_log: import_log,
        event_type: "rating_changed", old_value: "B", new_value: "A")

      get company_path(company)

      expect(response.body).not_to include("Rating changed")
    end

    it "omits the card entirely when there are no granted/revoked events" do
      change_event.destroy

      get company_path(company)

      expect(response.body).not_to include("Licence History")
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

      it "synchronously enriches the company profile in the same request, with no reload needed" do
        expect(CompanyEnricher).to receive(:enrich!).and_wrap_original do |method, company|
          company.update!(company_number: "03900676", registered_office_address: "123 Street", enriched_at: Time.current)
          company
        end
        allow(CompaniesHouseClient).to receive(:fetch_profile).with("03900676").and_return({
          company_status: "active",
          company_type: "ltd",
          date_of_creation: "2016-07-26",
          sic_codes: [ "62090" ]
        })

        get enrich_company_path(company)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("Active")
        expect(response.body).to include("Private Limited Company")
        expect(company.reload.company_profile).to be_present
      end

      it "returns the profile summary partial when card: profile_summary is requested" do
        expect(CompanyEnricher).to receive(:enrich!).and_wrap_original do |method, company|
          company.update!(company_number: "03900676", enriched_at: Time.current)
          company
        end
        allow(CompaniesHouseClient).to receive(:fetch_profile).with("03900676").and_return({
          company_status: "active",
          company_type: "ltd",
          date_of_creation: "2016-07-26",
          sic_codes: [ "62090" ]
        })

        get enrich_company_path(company, card: :profile_summary)

        expect(response).to have_http_status(:success)
        expect(response.body).to include("company_profile_summary_#{company.id}")
        expect(response.body).to include("According to Companies House")
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

      it "still enriches the company profile even though the company itself was already enriched" do
        allow(CompaniesHouseClient).to receive(:fetch_profile).with("99999999").and_return({
          company_status: "dissolved",
          company_type: "ltd",
          date_of_creation: "2010-01-01",
          sic_codes: [ "62090" ]
        })

        get enrich_company_path(company, card: :profile_summary)

        expect(response).to have_http_status(:success)
        expect(company.reload.company_profile.company_status).to eq("dissolved")
      end
    end
  end
end
