require "rails_helper"

RSpec.describe SponsorLicenceHistoricalObservation, type: :model do
  describe "validations" do
    subject { build(:sponsor_licence_historical_observation) }

    it { is_expected.to validate_presence_of(:route) }
    it { is_expected.to validate_presence_of(:event_type) }
    it { is_expected.to validate_inclusion_of(:event_type).in_array(described_class::EVENT_TYPES) }
    it { is_expected.to validate_presence_of(:occurred_before) }
    it { is_expected.to validate_presence_of(:wayback_timestamp) }
    it { is_expected.to validate_presence_of(:source_csv_url) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:company) }
  end

  describe "scopes" do
    let!(:added) { create(:sponsor_licence_historical_observation, event_type: "added") }
    let!(:removed) { create(:sponsor_licence_historical_observation, event_type: "removed") }

    it ".additions returns only added events" do
      expect(described_class.additions).to contain_exactly(added)
    end

    it ".removals returns only removed events" do
      expect(described_class.removals).to contain_exactly(removed)
    end
  end

  describe "#wayback_url" do
    it "reconstructs the archive.org URL from the stored timestamp and source URL" do
      observation = build(:sponsor_licence_historical_observation,
        wayback_timestamp: "20220112122447",
        source_csv_url: "https://assets.publishing.service.gov.uk/file1.csv")

      expect(observation.wayback_url).to eq("https://web.archive.org/web/20220112122447/https://assets.publishing.service.gov.uk/file1.csv")
    end
  end

  describe "#date_range_description" do
    it "describes a bounded window when occurred_after is present" do
      observation = build(:sponsor_licence_historical_observation,
        occurred_after: Time.zone.parse("2022-01-12"),
        occurred_before: Time.zone.parse("2022-01-19"))

      expect(observation.date_range_description).to eq("between 12 Jan 2022 and 19 Jan 2022")
    end

    it "describes an unbounded window when occurred_after is absent" do
      observation = build(:sponsor_licence_historical_observation,
        occurred_after: nil,
        occurred_before: Time.zone.parse("2022-01-19"))

      expect(observation.date_range_description).to eq("no later than 19 Jan 2022")
    end
  end
end
