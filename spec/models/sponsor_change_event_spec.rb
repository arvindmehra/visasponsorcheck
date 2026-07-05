require "rails_helper"

RSpec.describe SponsorChangeEvent, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:company) }
    it { is_expected.to belong_to(:sponsor_import_log) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_inclusion_of(:event_type).in_array(SponsorChangeEvent::EVENT_TYPES) }
    it { is_expected.to validate_presence_of(:occurred_at) }
  end

  describe "scopes" do
    let(:company) { create(:company) }
    let(:import_log) { create(:sponsor_import_log) }
    let!(:added_event) do
      create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "added", occurred_at: 1.day.ago)
    end
    let!(:removed_event) do
      create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "removed", occurred_at: Time.current)
    end
    let!(:rating_changed_event) do
      create(:sponsor_change_event, company: company, sponsor_import_log: import_log, event_type: "rating_changed", occurred_at: 2.days.ago)
    end

    describe ".recent" do
      it "returns events ordered by occurred_at descending" do
        expect(SponsorChangeEvent.recent).to eq([ removed_event, added_event, rating_changed_event ])
      end
    end

    describe ".for_company" do
      it "filters events by company" do
        expect(SponsorChangeEvent.for_company(company)).to include(added_event)
      end
    end

    describe ".additions" do
      it "filters only added events" do
        expect(SponsorChangeEvent.additions).to eq([ added_event ])
      end
    end

    describe ".removals" do
      it "filters only removed events" do
        expect(SponsorChangeEvent.removals).to eq([ removed_event ])
      end
    end

    describe ".changes_only" do
      it "filters out additions and removals" do
        expect(SponsorChangeEvent.changes_only).to eq([ rating_changed_event ])
      end
    end
  end

  describe "instance helpers" do
    let(:company) { build(:company, name: "Test Corp") }
    let(:event) { build(:sponsor_change_event, company: company) }

    describe "#human_description" do
      it "returns correct description for added" do
        event.event_type = "added"
        expect(event.human_description).to eq("Added as a licensed sponsor")
      end

      it "returns correct description for removed" do
        event.event_type = "removed"
        expect(event.human_description).to eq("Removed from the sponsor register")
      end

      it "returns correct description for rating_changed" do
        event.assign_attributes(event_type: "rating_changed", old_value: "B", new_value: "A")
        expect(event.human_description).to eq('Rating changed from "B" to "A"')
      end

      it "returns correct description for status_changed" do
        event.assign_attributes(event_type: "status_changed", old_value: "removed", new_value: "active")
        expect(event.human_description).to eq("Status changed from removed to active")
      end

      it "returns correct description for route_changed" do
        event.assign_attributes(event_type: "route_changed", old_value: "Intra-Company Transfer", new_value: "Skilled Worker")
        expect(event.human_description).to eq('Route changed from "Intra-Company Transfer" to "Skilled Worker"')
      end

      it "returns correct description for licence_type_changed" do
        event.assign_attributes(event_type: "licence_type_changed", old_value: "Temporary Worker", new_value: "Worker")
        expect(event.human_description).to eq('Licence type changed from "Temporary Worker" to "Worker"')
      end
    end

    describe "#icon" do
      it "returns green checkmark for added" do
        event.event_type = "added"
        expect(event.icon).to eq("✅")
      end

      it "returns red cross for removed" do
        event.event_type = "removed"
        expect(event.icon).to eq("❌")
      end

      it "returns circular arrows for other events" do
        event.event_type = "rating_changed"
        expect(event.icon).to eq("🔄")
      end
    end
  end
end
