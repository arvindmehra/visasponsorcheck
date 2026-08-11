require "rails_helper"

RSpec.describe LocationNormalizer do
  describe ".normalize" do
    it "corrects spelling of Abbeywood" do
      expect(LocationNormalizer.normalize("Abbeywood")).to eq("Abbey Wood")
      expect(LocationNormalizer.normalize("abbeywood")).to eq("Abbey Wood")
    end

    it "corrects spelling of Abindgon" do
      expect(LocationNormalizer.normalize("Abindgon")).to eq("Abingdon")
    end

    it "corrects spelling of Abotts Langely" do
      expect(LocationNormalizer.normalize("Abotts Langely")).to eq("Abbots Langley")
    end

    it "preserves correct spelling" do
      expect(LocationNormalizer.normalize("London")).to eq("London")
    end

    it "strips and collapses whitespaces" do
      expect(LocationNormalizer.normalize("   London   ")).to eq("London")
    end
  end

  describe ".canonical_slug" do
    it "returns hyphenated slug for city with spaces" do
      expect(LocationNormalizer.canonical_slug("Abbey Wood")).to eq("abbey-wood")
    end

    it "returns hyphenated slug for misspelled city" do
      expect(LocationNormalizer.canonical_slug("abbeywood")).to eq("abbey-wood")
    end

    it "returns hyphenated slug for standard city" do
      expect(LocationNormalizer.canonical_slug("Newcastle-upon-Tyne")).to eq("newcastle-upon-tyne")
    end
  end

  describe ".canonical_name" do
    it "recovers display name for mapped slug" do
      expect(LocationNormalizer.canonical_name("abbey-wood")).to eq("Abbey Wood")
      expect(LocationNormalizer.canonical_name("abbots-langley")).to eq("Abbots Langley")
    end

    it "capitalizes non-mapped slugs" do
      expect(LocationNormalizer.canonical_name("london")).to eq("London")
      expect(LocationNormalizer.canonical_name("milton-keynes")).to eq("Milton Keynes")
    end
  end
end
