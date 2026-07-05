require "rails_helper"

RSpec.describe SponsorImportLog, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:sponsor_change_events).dependent(:nullify) }
  end

  describe "validations" do
    it { is_expected.to validate_presence_of(:source_url) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:status).in_array(SponsorImportLog::STATUSES) }
  end

  describe "scopes" do
    let!(:pending_log) { create(:sponsor_import_log, status: "pending", created_at: 2.days.ago) }
    let!(:done_log)    { create(:sponsor_import_log, status: "done", created_at: 1.day.ago) }
    let!(:failed_log)  { create(:sponsor_import_log, status: "failed", created_at: Time.current) }

    describe ".recent" do
      it "returns logs ordered by created_at descending" do
        expect(SponsorImportLog.recent).to eq([ failed_log, done_log, pending_log ])
      end
    end

    describe ".done" do
      it "returns done logs" do
        expect(SponsorImportLog.done).to eq([ done_log ])
      end
    end

    describe ".failed" do
      it "returns failed logs" do
        expect(SponsorImportLog.failed).to eq([ failed_log ])
      end
    end
  end

  describe "state transitions" do
    let(:log) { create(:sponsor_import_log, status: "pending") }

    describe "#start!" do
      it "transitions status to running and sets started_at" do
        log.start!
        expect(log.status).to eq("running")
        expect(log.started_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "#finish!" do
      before { log.start! }

      it "transitions status to done, sets completed_at and statistics" do
        stats = { total_rows: 100, new_licences: 5, updated_licences: 10, removed_licences: 2 }
        log.finish!(stats)

        expect(log.status).to eq("done")
        expect(log.completed_at).to be_within(1.second).of(Time.current)
        expect(log.total_rows).to eq(100)
        expect(log.new_licences).to eq(5)
        expect(log.updated_licences).to eq(10)
        expect(log.removed_licences).to eq(2)
      end
    end

    describe "#fail!" do
      before { log.start! }

      it "transitions status to failed, sets error message and completed_at" do
        log.fail!("Something went wrong")
        expect(log.status).to eq("failed")
        expect(log.error_message).to eq("Something went wrong")
        expect(log.completed_at).to be_within(1.second).of(Time.current)
      end
    end
  end

  describe "display helpers" do
    let(:log) { build(:sponsor_import_log) }

    describe "#duration" do
      it "returns difference between started_at and completed_at" do
        log.started_at = Time.utc(2026, 6, 1, 12, 0, 0)
        log.completed_at = Time.utc(2026, 6, 1, 12, 5, 30)
        expect(log.duration).to eq(330.0)
      end

      it "returns nil if either timestamp is missing" do
        log.started_at = nil
        log.completed_at = Time.current
        expect(log.duration).to be_nil
      end
    end

    describe "#summary" do
      it "returns formatted statistic summary string" do
        log.assign_attributes(total_rows: 500, new_licences: 20, updated_licences: 15, removed_licences: 3)
        expect(log.summary).to eq("500 rows — 20 new, 15 updated, 3 removed")
      end
    end
  end
end
