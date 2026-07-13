require "rails_helper"

RSpec.describe SponsorsHelper, type: :helper do
  describe "#company_summary_paragraph" do
    let(:company_0) { create(:company, id: 0, name: "Alpha Corp", town: "London", county: "Greater London") }
    let(:company_1) { create(:company, id: 1, name: "Beta Corp", town: "Manchester", county: nil) }
    let(:company_2) { create(:company, id: 2, name: "Gamma Corp", town: nil, county: nil) }

    context "when company has active sponsor licences" do
      it "returns correct content using template 0 when company.id % 3 == 0" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_0, [ licence ])

        expect(paragraph).to include("Alpha Corp is a registered employer based in London, Greater London, holding an A-rated sponsor licence for the Skilled Worker visa route.")
        expect(paragraph).to include("This licence is currently active.")
        expect(paragraph).to include("Data sourced from the UK Home Office Register of Licensed Sponsors, last verified on June 15, 2026.")
      end

      it "returns correct content using template 1 when company.id % 3 == 1" do
        licence = create(:sponsor_licence, company: company_1, rating: "B", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-07-01 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_1, [ licence ])

        expect(paragraph).to include("Based in Manchester, Beta Corp is a licensed UK sponsor holding a B-rated licence for the Skilled Worker visa route.")
        expect(paragraph).to include("The current status of this licence is active.")
        expect(paragraph).to include("last verified on July 1, 2026")
      end

      it "returns correct content using template 2 when company.id % 3 == 2" do
        licence = create(:sponsor_licence, company: company_2, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-07-05 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_2, [ licence ])

        expect(paragraph).to include("For the Skilled Worker visa route, Gamma Corp is an authorized sponsor with an A-rated licence. Located in the UK, this employer's licence is currently active.")
        expect(paragraph).to include("last verified on July 5, 2026")
      end

      it "appends the Companies House profile paragraph when the company has enriched profile data" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))
        company_0.create_company_profile!(
          company_status: "active",
          company_type: "ltd",
          date_of_creation: Date.new(2018, 3, 5),
          sic_code: 86900,
          sic_code_description: "Other human health activities",
          enriched_at: Time.current
        )

        paragraph = helper.company_summary_paragraph(company_0, [ licence ])

        expect(paragraph).to include("According to Companies House, Alpha Corp was incorporated on 5 March 2018 and is registered as a Private Limited Company.")
        expect(paragraph).to include("Its registered nature of business is Other human health activities.")
        expect(paragraph).to include("Companies House currently lists its status as active.")
      end

      it "does not append a profile paragraph when the company has no enriched profile" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_0, [ licence ])

        expect(paragraph).not_to include("According to Companies House")
      end

      it "handles multiple routes and ratings correctly" do
        licence_1 = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-15 12:00:00"))
        licence_2 = create(:sponsor_licence, company: company_0, rating: "B", route: "Creative Worker", status: "active", last_seen_at: Time.zone.parse("2026-06-20 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_0, [ licence_1, licence_2 ])

        expect(paragraph).to include("holding A and B-rated sponsor licences for the Creative Worker and Skilled Worker visa routes.")
        expect(paragraph).to include("These licences are currently active.")
        expect(paragraph).to include("last verified on June 20, 2026")
      end
    end

    context "when company has only removed/inactive sponsor licences" do
      it "returns correct removed content using template 0 when company.id % 3 == 0" do
        licence = create(:sponsor_licence, company: company_0, rating: "A", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-10 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_0, [ licence ])

        expect(paragraph).to include("Alpha Corp was previously a registered employer based in London, Greater London, but its UK visa sponsor licence is currently inactive (removed).")
        expect(paragraph).to include("last verified on May 10, 2026")
      end

      it "returns correct removed content using template 1 when company.id % 3 == 1" do
        licence = create(:sponsor_licence, company: company_1, rating: "B", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-15 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_1, [ licence ])

        expect(paragraph).to include("The UK visa sponsor licence for Beta Corp (located in Manchester) has been removed from the official register and is currently inactive.")
        expect(paragraph).to include("last verified on May 15, 2026")
      end

      it "returns correct removed content using template 2 when company.id % 3 == 2" do
        licence = create(:sponsor_licence, company: company_2, rating: "A", route: "Skilled Worker", status: "removed", last_seen_at: Time.zone.parse("2026-05-20 12:00:00"))

        paragraph = helper.company_summary_paragraph(company_2, [ licence ])

        expect(paragraph).to include("Based in the UK, Gamma Corp no longer holds an active sponsor licence on the UK visa register. This licence is currently inactive (removed).")
        expect(paragraph).to include("last verified on May 20, 2026")
      end
    end
  end

  describe "#company_profile_paragraph" do
    let(:company) { create(:company, name: "Alpha Corp", town: "London", county: "Greater London") }

    it "returns nil when the company has no company_profile" do
      expect(helper.company_profile_paragraph(company)).to be_nil
    end

    it "returns nil when the profile exists but has never been enriched" do
      company.create_company_profile!(enriched_at: nil)

      expect(helper.company_profile_paragraph(company)).to be_nil
    end

    it "returns a readable, multi-sentence paragraph built from the enriched profile" do
      company.create_company_profile!(
        company_status: "active",
        company_type: "ltd",
        date_of_creation: Date.new(2018, 3, 5),
        sic_code: 86900,
        sic_code_description: "Other human health activities",
        enriched_at: Time.current
      )

      paragraph = helper.company_profile_paragraph(company)

      expect(paragraph).to eq(
        "According to Companies House, Alpha Corp was incorporated on 5 March 2018 and is registered as a Private Limited Company. " \
        "Its registered nature of business is Other human health activities. " \
        "Companies House currently lists its status as active."
      )
    end

    it "omits missing pieces gracefully" do
      company.create_company_profile!(company_status: "dissolved", enriched_at: Time.current)

      paragraph = helper.company_profile_paragraph(company)

      expect(paragraph).to eq("Companies House currently lists its status as dissolved.")
    end
  end

  describe "#rating_word" do
    it "returns the standard phrase for A" do
      expect(helper.rating_word("A")).to eq("an A-rated")
    end

    it "returns the standard phrase for B" do
      expect(helper.rating_word("B")).to eq("a B-rated")
    end

    it "does not call a Provisional licence B-rated" do
      expect(helper.rating_word("Provisional")).to eq("a Provisional")
    end
  end

  describe "#rating_badge" do
    it "renders an emerald square for A" do
      html = helper.rating_badge("A")
      expect(html).to include("bg-emerald-50")
      expect(html).to include(">A<")
    end

    it "renders an amber square for B" do
      html = helper.rating_badge("B")
      expect(html).to include("bg-amber-50")
    end

    it "renders a neutral pill (not amber/B styling) for Provisional" do
      html = helper.rating_badge("Provisional")
      expect(html).not_to include("bg-amber-50")
      expect(html).to include("bg-slate-50")
      expect(html).to include("Provisional")
    end
  end

  describe "#company_expanded_profile_paragraphs" do
    let(:company) { create(:company, id: 7, name: "Delta Corp", town: "Bristol") }

    context "when the company has an active licence" do
      let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker", status: "active") }

      it "returns regional, industry, and verification paragraphs with real data interpolated" do
        paragraphs = helper.company_expanded_profile_paragraphs(company, [ licence ])

        expect(paragraphs.size).to eq(3)
        expect(paragraphs[0]).to include("Delta Corp").and include("Bristol")
        expect(paragraphs[1]).to include("Delta Corp").and include("Skilled Worker")
        expect(paragraphs[2]).to include("Delta Corp").and include("currently shown as active")
      end

      it "combined with the base licence summary, comfortably clears 250 words" do
        base = helper.company_licence_summary_paragraph(company, [ licence ])
        expanded = helper.company_expanded_profile_paragraphs(company, [ licence ])
        total_words = ([ base ] + expanded).join(" ").split.size

        expect(total_words).to be >= 250
      end
    end

    context "when the company has no active licence (removed)" do
      let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker", status: "removed") }

      it "skips the industry paragraph but still returns regional and verification paragraphs" do
        paragraphs = helper.company_expanded_profile_paragraphs(company, [ licence ])

        expect(paragraphs.size).to eq(2)
        expect(paragraphs.last).to include("currently shown as removed")
      end
    end
  end
end
