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
  end
end

