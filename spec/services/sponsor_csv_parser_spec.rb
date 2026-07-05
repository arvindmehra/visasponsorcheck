require "rails_helper"
require "tempfile"

RSpec.describe SponsorCsvParser do
  describe ".call" do
    let(:temp_csv) { Tempfile.new([ "test_sponsors", ".csv" ]) }

    after do
      temp_csv.close
      temp_csv.unlink
    end

    it "parses standard rows and normalises headers" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
        "Bossmans Retail Ltd",Abergavenny,,Worker (B rating),Creative Worker
      CSV
      temp_csv.rewind

      result = SponsorCsvParser.call(temp_csv.path)

      expect(result.size).to eq(2)
      expect(result[0]).to eq({
        organisation_name: "BOLTWHIZ LIMITED",
        town: "Dunfermline",
        county: "Scotland",
        type_and_rating: "Worker (A rating)",
        route: "Skilled Worker"
      })
      expect(result[1]).to eq({
        organisation_name: "Bossmans Retail Ltd",
        town: "Abergavenny",
        county: nil,
        type_and_rating: "Worker (B rating)",
        route: "Creative Worker"
      })
    end

    it "handles alternative header naming and trailing spaces" do
      temp_csv.write(<<~CSV)
        Company Name,Town ,County,Rating,Route
        "ACME Corp",London,Greater London,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      result = SponsorCsvParser.call(temp_csv.path)

      expect(result.first).to eq({
        organisation_name: "ACME Corp",
        town: "London",
        county: "Greater London",
        type_and_rating: "Worker (A rating)",
        route: "Skilled Worker"
      })
    end
  end
end
