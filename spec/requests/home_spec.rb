require "rails_helper"

RSpec.describe "Homes", type: :request do
  describe "GET /" do
    it "returns HTTP success and renders homepage with stats" do
      create(:sponsor_licence, status: "active") # Ensure some records exist
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Sponsor Licence Checker")
    end

    context "when a sync has completed" do
      let!(:import_log) { create(:sponsor_import_log) }
      let(:company) { create(:company) }

      it "counts change events from the last 24 hours, not older ones" do
        create_list(:sponsor_change_event, 3, company: company, sponsor_import_log: import_log, event_type: "added", occurred_at: 2.hours.ago)
        create_list(:sponsor_change_event, 2, company: company, sponsor_import_log: import_log, event_type: "rating_changed", occurred_at: 2.hours.ago)
        create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "removed", occurred_at: 2.hours.ago)
        # Older than 24h — should not be counted
        create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "added", occurred_at: 25.hours.ago)

        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Today's Register")
        expect(response.body).to include("+3")
        expect(response.body).to include(">2<")
        expect(response.body).to include(">1<")
      end
    end

    context "when no sync has completed yet" do
      it "does not render the Today's Register section" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).not_to include("Today's Register")
      end
    end
  end
end
