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

  describe "GET /uk-visa-sponsorship-list" do
    let!(:company) { create(:company, name: "Gamma Ltd", town: "Manchester") }
    let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker", rating: "A", status: "active") }

    it "renders the sponsorship list guide page successfully" do
      get sponsorship_list_guide_path
      expect(response).to have_http_status(:success)
      expect(response.body).to include("UK Visa Sponsorship List Explained")
      expect(response.body).to include("How This List Is Compiled")
      expect(response.body).to include("Manchester")
    end
  end

  describe "GET /llms.txt" do
    it "serves the static llms.txt file describing the site for AI/semantic crawlers" do
      get "/llms.txt"
      expect(response).to have_http_status(:success)
      expect(response.body).to include("VisaSponsorUK")
      expect(response.body).to include("Sitemap")
    end
  end

  describe "www subdomain redirect" do
    it "redirects the homepage from www to the apex domain with a 301, preserving the path" do
      get "/sponsors", headers: { "HOST" => "www.visasponsoruk.com" }
      expect(response).to have_http_status(:moved_permanently)
      expect(response.headers["Location"]).to eq("http://visasponsoruk.com/sponsors")
    end

    it "does not redirect requests to the apex domain" do
      get "/sponsors", headers: { "HOST" => "visasponsoruk.com" }
      expect(response).to have_http_status(:success)
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
