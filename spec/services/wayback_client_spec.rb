require "rails_helper"

RSpec.describe WaybackClient do
  describe ".list_snapshots" do
    it "parses the CDX JSON response into timestamp/url pairs, dropping the header row" do
      cdx_body = [
        [ "timestamp", "original" ],
        [ "20220112122447", "https://www.gov.uk/some-page" ],
        [ "20220204153920", "https://www.gov.uk/some-page" ]
      ].to_json
      response = double(code: 200, body: cdx_body)

      expect(HTTParty).to receive(:get).with(
        WaybackClient::CDX_BASE_URL,
        hash_including(query: hash_including(url: "https://www.gov.uk/some-page"))
      ).and_return(response)

      result = described_class.list_snapshots(url: "https://www.gov.uk/some-page")

      expect(result).to eq([
        { timestamp: "20220112122447", url: "https://www.gov.uk/some-page" },
        { timestamp: "20220204153920", url: "https://www.gov.uk/some-page" }
      ])
    end

    it "returns an empty array when there are no captures" do
      response = double(code: 200, body: "[]")
      allow(HTTParty).to receive(:get).and_return(response)

      expect(described_class.list_snapshots(url: "https://www.gov.uk/nothing-here")).to eq([])
    end

    it "raises when the CDX query fails" do
      response = double(code: 503, body: "")
      allow(HTTParty).to receive(:get).and_return(response)

      expect { described_class.list_snapshots(url: "https://www.gov.uk/some-page") }.to raise_error(/CDX query failed/)
    end

    it "passes from/to bounds through to the query when given" do
      response = double(code: 200, body: "[]")
      expect(HTTParty).to receive(:get).with(
        WaybackClient::CDX_BASE_URL,
        hash_including(query: hash_including(from: "20211201", to: "20221231"))
      ).and_return(response)

      described_class.list_snapshots(url: "https://www.gov.uk/some-page", from: "20211201", to: "20221231")
    end
  end

  describe ".fetch" do
    it "downloads the archived content to a temp file and returns its path" do
      response = double(code: 200)
      expect(HTTParty).to receive(:get).with(
        "https://web.archive.org/web/20220112122447/https://example.com/file.csv",
        stream_body: true, timeout: 120
      ).and_yield("row1,row2\n").and_return(response)

      path = described_class.fetch(timestamp: "20220112122447", original_url: "https://example.com/file.csv")

      expect(File.exist?(path)).to be true
      expect(File.read(path)).to eq("row1,row2\n")
      File.delete(path)
    end

    it "raises and cleans up the temp file when the fetch fails" do
      response = double(code: 404)
      allow(HTTParty).to receive(:get).and_yield("").and_return(response)

      expect {
        described_class.fetch(timestamp: "20220112122447", original_url: "https://example.com/missing.csv")
      }.to raise_error(/Failed to fetch Wayback snapshot/)
    end
  end
end
