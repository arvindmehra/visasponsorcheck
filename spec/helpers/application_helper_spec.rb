require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  let(:pagy_page_1) { instance_double(Pagy, page: 1, last: 3) }
  let(:pagy_page_2) { instance_double(Pagy, page: 2, last: 3) }

  describe "#paginated_meta_title" do
    it "returns the base title unchanged on page 1" do
      expect(helper.paginated_meta_title("UK Visa Sponsors", pagy_page_1)).to eq("UK Visa Sponsors")
    end

    it "appends the page number on page 2+" do
      expect(helper.paginated_meta_title("UK Visa Sponsors", pagy_page_2)).to eq("UK Visa Sponsors (Page 2)")
    end

    it "returns the base title unchanged when pagy is nil" do
      expect(helper.paginated_meta_title("UK Visa Sponsors", nil)).to eq("UK Visa Sponsors")
    end
  end

  describe "#paginated_meta_description" do
    it "returns the base description unchanged on page 1" do
      expect(helper.paginated_meta_description("Browse the register.", pagy_page_1)).to eq("Browse the register.")
    end

    it "appends page context on page 2+, so paginated pages don't duplicate page 1's description" do
      expect(helper.paginated_meta_description("Browse the register.", pagy_page_2))
        .to eq("Browse the register. (Page 2 of 3).")
    end
  end

  describe "#trusted_external_link_to" do
    it "drops nofollow for gov.uk domains" do
      html = helper.trusted_external_link_to("https://www.gov.uk/government/publications/register-of-licensed-sponsors-workers") { "Register" }
      expect(html).to include('rel="noopener"')
      expect(html).not_to include("nofollow")
    end

    it "drops nofollow for gov.uk subdomains like Companies House" do
      html = helper.trusted_external_link_to("https://find-and-update.company-information.service.gov.uk/company/123") { "Companies House" }
      expect(html).to include('rel="noopener"')
      expect(html).not_to include("nofollow")
    end

    it "keeps nofollow for untrusted domains" do
      html = helper.trusted_external_link_to("https://www.linkedin.com/search") { "LinkedIn" }
      expect(html).to include('rel="noopener noreferrer nofollow"')
    end

    it "always sets target=_blank" do
      html = helper.trusted_external_link_to("https://www.gov.uk/foo") { "GOV.UK" }
      expect(html).to include('target="_blank"')
    end
  end
end
