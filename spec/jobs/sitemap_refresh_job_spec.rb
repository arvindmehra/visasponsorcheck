require "rails_helper"
require "rake"

RSpec.describe SitemapRefreshJob, type: :job do
  before :all do
    Rake.application = Rake::Application.new
  end

  describe "#perform" do
    it "invokes the sitemap:create rake task" do
      # Stub tasks
      allow(Rake::Task).to receive(:[]).and_return(double(invoke: true))

      expect(Rake::Task).to receive(:[]).with("sitemap:create")
      SitemapRefreshJob.perform_now
    end

    it "rescues and logs errors if rake task fails" do
      allow(Rake::Task).to receive(:[]).with("sitemap:clean").and_raise(StandardError.new("clean failed"))
      allow(Rake::Task).to receive(:[]).with("sitemap:create").and_raise(StandardError.new("create failed"))

      expect(Rails.logger).to receive(:error).with("Sitemap clean failed: clean failed")
      expect(Rails.logger).to receive(:error).with("Sitemap create failed: create failed")

      expect { SitemapRefreshJob.perform_now }.not_to raise_error
    end
  end
end
