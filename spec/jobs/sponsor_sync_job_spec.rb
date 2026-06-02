require "rails_helper"

RSpec.describe SponsorSyncJob, type: :job do
  describe "#perform" do
    it "calls SponsorImporter" do
      expect(SponsorImporter).to receive(:call)
      SponsorSyncJob.perform_now
    end
  end
end
