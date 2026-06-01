require "rails_helper"

RSpec.describe SponsorLicence, type: :model do
  describe "validations" do
    subject { build(:sponsor_licence) }

    it { is_expected.to validate_presence_of(:organisation_name) }
    it { is_expected.to validate_presence_of(:licence_type) }
    it { is_expected.to validate_presence_of(:rating) }
    it { is_expected.to validate_presence_of(:route) }
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_inclusion_of(:licence_type).in_array(SponsorLicence::LICENCE_TYPES) }
    it { is_expected.to validate_inclusion_of(:rating).in_array(SponsorLicence::RATINGS) }
    it { is_expected.to validate_inclusion_of(:status).in_array(SponsorLicence::STATUSES) }
  end

  describe "associations" do
    it { is_expected.to belong_to(:company) }
  end

  describe ".parse_type_and_rating" do
    it "parses Worker A rating" do
      result = described_class.parse_type_and_rating("Worker (A rating)")
      expect(result).to eq({ licence_type: "Worker", rating: "A" })
    end

    it "parses Temporary Worker A rating" do
      result = described_class.parse_type_and_rating("Temporary Worker (A rating)")
      expect(result).to eq({ licence_type: "Temporary Worker", rating: "A" })
    end

    it "parses Worker B rating" do
      result = described_class.parse_type_and_rating("Worker (B rating)")
      expect(result).to eq({ licence_type: "Worker", rating: "B" })
    end

    it "is case insensitive" do
      result = described_class.parse_type_and_rating("worker (a rating)")
      expect(result[:rating]).to eq("A")
    end

    it "returns nil for blank input" do
      expect(described_class.parse_type_and_rating("")).to be_nil
      expect(described_class.parse_type_and_rating(nil)).to be_nil
    end

    it "returns nil for unrecognised format" do
      expect(described_class.parse_type_and_rating("Unknown format")).to be_nil
    end
  end

  describe "#active?" do
    it "returns true for active status" do
      licence = build(:sponsor_licence, status: "active")
      expect(licence.active?).to be true
    end

    it "returns false for removed status" do
      licence = build(:sponsor_licence, :removed)
      expect(licence.active?).to be false
    end
  end

  describe "uniqueness of route per company" do
    let(:company) { create(:company) }

    it "prevents duplicate route for same company" do
      create(:sponsor_licence, company: company, route: "Skilled Worker")
      duplicate = build(:sponsor_licence, company: company, route: "Skilled Worker")
      expect(duplicate).not_to be_valid
    end

    it "allows same route for different companies" do
      create(:sponsor_licence, company: company, route: "Skilled Worker")
      other_company = create(:company)
      licence = build(:sponsor_licence, company: other_company, route: "Skilled Worker")
      expect(licence).to be_valid
    end
  end
end
