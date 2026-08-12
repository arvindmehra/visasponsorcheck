require "rails_helper"

RSpec.describe "Blogs", type: :request do
  let!(:published_blog) do
    Blog.create!(
      title: "UK Sponsor Licence Guide 2026",
      category: "Sponsor Licence",
      meta_description: "Comprehensive guide for UK employers seeking a sponsor licence.",
      content_html: "<h2>Overview</h2><p>Here are the step-by-step instructions for 2026 applications.</p>",
      status: "published",
      quality_score: 95,
      published_at: Time.current
    )
  end

  let!(:draft_blog) do
    Blog.create!(
      title: "Draft Article",
      category: "Compliance",
      meta_description: "Draft meta",
      content_html: "<p>Draft text</p>",
      status: "pending_review",
      quality_score: 85
    )
  end

  describe "GET /blogs" do
    it "renders the blogs index page successfully" do
      get blogs_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UK Sponsor Licence Guide 2026")
      expect(response.body).not_to include("Draft Article")
    end

    it "filters blogs by category" do
      get blogs_path(category: "Sponsor Licence")
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UK Sponsor Licence Guide 2026")
    end
  end

  describe "GET /blog/:slug" do
    it "renders the blog show page successfully" do
      get blog_path(published_blog.slug)
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("UK Sponsor Licence Guide 2026")
    end

    it "returns 404 for draft blog" do
      get blog_path(draft_blog.slug)
      expect(response).to have_http_status(:not_found)
    end
  end
end
