require "rails_helper"

RSpec.describe SponsorLicenceRemovalJob, type: :job do
  let(:company) { create(:company) }
  let(:import_log) { create(:sponsor_import_log, started_at: 1.hour.ago) }

  describe "#perform" do
    it "marks the company's stale active licence as removed" do
      licence = create(:sponsor_licence, company: company, status: "active", last_seen_at: 2.days.ago)
      event = create(:sponsor_change_event, company: company, sponsor_import_log: import_log,
                                             event_type: "removed", occurred_at: Time.current)

      described_class.perform_now(event.id)

      expect(licence.reload.status).to eq("removed")
    end

    it "does not touch a different route's licence that is still active as of this sync" do
      sync_time = 1.minute.ago
      stale_licence = create(:sponsor_licence, company: company, route: "Skilled Worker",
                                                status: "active", last_seen_at: 2.days.ago)
      # Seen in the very same sync the "removed" event came from — the
      # licence still present in this batch, so it must be left alone.
      fresh_licence = create(:sponsor_licence, company: company, route: "Temporary Worker",
                                                status: "active", last_seen_at: sync_time)
      event = create(:sponsor_change_event, company: company, sponsor_import_log: import_log,
                                             event_type: "removed", occurred_at: sync_time)

      described_class.perform_now(event.id)

      expect(stale_licence.reload.status).to eq("removed")
      expect(fresh_licence.reload.status).to eq("active")
    end

    it "does nothing when the company can no longer be found (guard clause)" do
      licence = create(:sponsor_licence, company: company, status: "active", last_seen_at: 2.days.ago)
      event = create(:sponsor_change_event, company: company, sponsor_import_log: import_log,
                                             event_type: "removed", occurred_at: Time.current)
      # A DB-level foreign key means an event can't really point at a deleted
      # company, so simulate the "not found" branch directly rather than
      # trying to construct that state for real.
      allow(Company).to receive(:find_by).with(id: company.id).and_return(nil)

      expect { described_class.perform_now(event.id) }.not_to raise_error
      expect(licence.reload.status).to eq("active")
    end

    it "does nothing for a non-removed event" do
      licence = create(:sponsor_licence, company: company, status: "active", last_seen_at: 2.days.ago)
      event = create(:sponsor_change_event, company: company, sponsor_import_log: import_log,
                                             event_type: "added", occurred_at: Time.current)

      described_class.perform_now(event.id)

      expect(licence.reload.status).to eq("active")
    end

    it "does nothing when the event no longer exists" do
      expect { described_class.perform_now(-1) }.not_to raise_error
    end
  end
end
