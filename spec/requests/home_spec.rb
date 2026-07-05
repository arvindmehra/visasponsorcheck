require "rails_helper"

RSpec.describe "Homes", type: :request do
  describe "GET /" do
    it "returns HTTP success and renders homepage with stats" do
      create(:sponsor_licence, status: "active") # Ensure some records exist
      get root_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("UK Visa Sponsor Registry")
      expect(response.body).to include("Active Sponsors")
    end
  end
end
