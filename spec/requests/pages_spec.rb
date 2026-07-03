require "rails_helper"

RSpec.describe "Static Pages", type: :request do
  describe "GET /faq" do
    it "renders the FAQ page successfully" do
      get faq_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("UK Visa Sponsor — Frequently Asked Questions")
      expect(response.body).to include("What is a UK sponsor licence?")
      expect(response.body).to include("A-rated sponsor mean")
    end
  end
end
