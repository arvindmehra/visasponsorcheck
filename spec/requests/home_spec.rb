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

      before do
        create_list(:sponsor_change_event, 14, sponsor_import_log: import_log, event_type: "added")
        create_list(:sponsor_change_event, 9, sponsor_import_log: import_log, event_type: "rating_changed")
        create_list(:sponsor_change_event, 6, sponsor_import_log: import_log, event_type: "removed")
      end

      it "shows counts derived from this sync's SponsorChangeEvent records, not the log's stored aggregate columns" do
        get root_path
        expect(response).to have_http_status(:success)
        expect(response.body).to include("Today's Register")
        expect(response.body).to include("+14")
        expect(response.body).to include("9")
        expect(response.body).to include("6")
      end

      it "shows the most recently created log's events, not an older one's" do
        older_log = create(:sponsor_import_log, created_at: 3.days.ago, started_at: 3.days.ago, completed_at: 3.days.ago)
        create_list(:sponsor_change_event, 99, sponsor_import_log: older_log, event_type: "added", occurred_at: 3.days.ago)

        get root_path
        expect(response.body).to include("+14")
        expect(response.body).not_to include("+99")
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
