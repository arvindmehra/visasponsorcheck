require "rails_helper"

RSpec.describe SponsorCsvDownloader do
  describe ".call" do
    let(:gov_uk_url) { SponsorCsvDownloader::GOV_UK_URL }
    let(:mock_csv_url) { "https://assets.publishing.service.gov.uk/media/123/Worker.csv" }

    context "when a local file is provided" do
      it "returns local file info directly" do
        temp_source = Tempfile.new("dummy_local_source.csv")
        file_path = temp_source.path
        result = SponsorCsvDownloader.call(file_path)
        expect(result[:path]).to eq(file_path)
        expect(result[:url]).to eq(file_path)
        expect(result[:filename]).to eq(File.basename(file_path))
        temp_source.close
        temp_source.unlink
      end
    end

    context "when scraping gov.uk" do
      it "scrapes the page and downloads the CSV" do
        # Mock the scrape request
        html_response = double(code: 200, body: '<a href="' + mock_csv_url + '">CSV Link</a>')
        expect(HTTParty).to receive(:get).with(gov_uk_url).and_return(html_response)

        # Mock the download request
        csv_response = double(code: 200)
        expect(HTTParty).to receive(:get).with(mock_csv_url, stream_body: true).and_yield("row1,row2").and_return(csv_response)

        result = SponsorCsvDownloader.call
        expect(result[:url]).to eq(mock_csv_url)
        expect(result[:filename]).to eq("Worker.csv")
        expect(File.exist?(result[:path])).to be true

        # Clean up
        File.delete(result[:path]) if File.exist?(result[:path])
      end
    end
  end
end
