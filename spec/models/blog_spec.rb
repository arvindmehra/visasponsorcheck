require "rails_helper"

RSpec.describe Blog, type: :model do
  describe "validations" do
    it "is valid with valid attributes" do
      blog = Blog.new(
        title: "UK Skilled Worker Visa Updates 2026",
        category: "Immigration News",
        meta_description: "Overview of official changes to UK Skilled Worker visa requirements in 2026.",
        content_html: "<h2>Overview</h2><p>Here are the key details on 2026 rules.</p>",
        status: "published",
        quality_score: 90
      )
      expect(blog).to be_valid
    end

    it "generates a slug automatically on creation" do
      blog = Blog.create!(
        title: "Sponsor Licence Audit Checklist 2026",
        category: "Compliance",
        meta_description: "Audit guide for UK sponsor licence holders.",
        content_html: "<h2>Checklist</h2><p>Steps to pass your Home Office audit.</p>",
        status: "published"
      )
      expect(blog.slug).to eq("sponsor-licence-audit-checklist-2026")
    end

    it "rejects invalid categories" do
      blog = Blog.new(category: "Invalid Category")
      expect(blog).not_to be_valid
      expect(blog.errors[:category]).to include("is not included in the list")
    end

    it "rejects invalid quality scores" do
      blog = Blog.new(quality_score: 150)
      expect(blog).not_to be_valid
      expect(blog.errors[:quality_score]).to include("must be less than or equal to 100")
    end
  end

  describe "scopes" do
    before do
      Blog.create!(
        title: "Published News",
        category: "Immigration News",
        meta_description: "Desc",
        content_html: "<p>Text</p>",
        status: "published",
        published_at: 1.day.ago
      )

      Blog.create!(
        title: "Pending Draft",
        category: "Compliance",
        meta_description: "Desc",
        content_html: "<p>Text</p>",
        status: "pending_review"
      )
    end

    it "filters by published status" do
      expect(Blog.published.count).to eq(1)
      expect(Blog.published.first.title).to eq("Published News")
    end

    it "filters by category" do
      expect(Blog.by_category("Compliance").count).to eq(1)
    end

    it "searches by query string" do
      expect(Blog.search_by_query("News").count).to eq(1)
    end
  end
end
