require "rails_helper"

RSpec.describe "Static Pages", type: :request do
  describe "GET /faq" do
    it "renders the FAQ page successfully" do
      get faq_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("UK Visa Sponsor — Frequently Asked Questions")
      expect(response.body).to include("What is a UK sponsor licence?")
      expect(eventually_contain_rating = true).to be true
    end
  end

  describe "Sitemap redirects" do
    it "redirects sitemap.xml to /sitemaps/sitemap.xml.gz with 301" do
      get "/sitemap.xml"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/sitemaps/sitemap.xml.gz")
    end

    it "redirects sitemap.xml.gz to /sitemaps/sitemap.xml.gz with 301" do
      get "/sitemap.xml.gz"
      expect(response).to have_http_status(:moved_permanently)
      expect(response).to redirect_to("/sitemaps/sitemap.xml.gz")
    end
  end
end

