require "rails_helper"

RSpec.describe SponsorsHelper, type: :helper do
  describe "#company_summary_paragraph" do
    let(:company_0) { create(:company, id: 0, name: "Alpha Corp", town: "London", county: "Greater London") }
    let(:company_1) { create(:company, id: 1, name: "Beta Corp", town: "Manchester", county: nil) }
    let(:company_2) { create(:company, id: 2, name: "Gamma Corp", town: nil, county: nil) }

    context "when company has active sponsor licences" do
      it "returns correct content using template 0 when company.id % 3 == 0" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_0, [licence])
        
        expect(paragraph).to include("Alpha Corp is a registered employer based in London, Greater London, holding an A-rated sponsor licence for the Skilled Worker visa route.")
        expect(paragraph).to include("This licence is currently active.")
        expect(paragraph).to include("Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on June 15, 2026.")
      end

      it "returns correct content using template 1 when company.id % 3 == 1" do
        licence = create(:sponsor_licence, company: company_1, rating: "B", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-07-01 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_1, [licence])
        
        expect(paragraph).to include("Based in Manchester, Beta Corp is a licensed UK sponsor holding a B-rated licence for the Skilled Worker visa route.")
        expect(paragraph).to include("The current status of this licence is active.")
        expect(paragraph).to include("last verified on July 1, 2026")
      end

      it "returns correct content using template 2 when company.id % 3 == 2" do
        licence = create(:sponsor_licence, company: company_2, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-07-05 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_2, [licence])
        
        expect(paragraph).to include("For the Skilled Worker visa route, Gamma Corp is an authorized sponsor with an A-rated licence. Located in the UK, this employer's licence is currently active.")
        expect(paragraph).to include("last verified on July 5, 2026")
      end

      it "handles multiple routes and ratings correctly" do
        licence_1 = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))
        licence_2 = create(:sponsor_licence, company: company_0, rating: "B", route: "Creative Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-20 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_0, [licence_1, licence_2])
        
        expect(paragraph).to include("holding A and B-rated sponsor licences for the Creative Worker and Skilled Worker visa routes.")
        expect(paragraph).to include("These licences are currently active.")
        expect(paragraph).to include("last verified on June 20, 2026")
      end
    end

    context "when company has only removed/inactive sponsor licences" do
      it "returns correct removed content using template 0 when company.id % 3 == 0" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-10 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_0, [licence])
        
        expect(paragraph).to include("Alpha Corp was previously a registered employer based in London, Greater London, but its UK visa sponsor licence is currently inactive (removed).")
        expect(paragraph).to include("last verified on May 10, 2026")
      end

      it "returns correct removed content using template 1 when company.id % 3 == 1" do
        licence = create(:sponsor_licence, company: company_1, rating: "B", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-15 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_1, [licence])
        
        expect(paragraph).to include("The UK visa sponsor licence for Beta Corp (located in Manchester) has been removed from the official register and is currently inactive.")
        expect(paragraph).to include("last verified on May 15, 2026")
      end

      it "returns correct removed content using template 2 when company.id % 3 == 2" do
        licence = create(:sponsor_licence, company: company_2, rating: "A", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-20 12:00:00"))
        
        paragraph = helper.company_summary_paragraph(company_2, [licence])
        
        expect(paragraph).to include("Based in the UK, Gamma Corp no longer holds an active sponsor licence on the UK visa register. This licence is currently inactive (removed).")
        expect(paragraph).to include("last verified on May 20, 2026")
      end
    end
  end
end
