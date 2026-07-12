require "rails_helper"

RSpec.describe SearchLog, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:query) }
    it { is_expected.to validate_numericality_of(:results_count).is_greater_than_or_equal_to(0) }

    it "is valid with a query and a results_count" do
      log = build(:search_log, query: "boltwhiz", results_count: 3)
      expect(log).to be_valid
    end

    it "is valid with a zero results_count" do
      log = build(:search_log, results_count: 0)
      expect(log).to be_valid
    end
  end
end
