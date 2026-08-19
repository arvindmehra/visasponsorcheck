require "rails_helper"

RSpec.describe SponsorCsvDownloader do
  describe ".call" do
    let(:mock_csv_url) { "https://assets.publishing.service.gov.uk/media/123/Worker.csv" }
    let(:content_api_url) { "https://www.gov.uk/api/content/government/publications/register-of-licensed-sponsors-workers" }

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

    context "when using Content API (primary)" do
      it "fetches the CSV URL from the Content API" do
        api_json = {
          "details" => {
            "attachments" => [
              {
                "content_type" => "text/csv",
                "filename" => "SP_-_Worker_and_Temporary_Worker_Web_Register_-_2026-08-19.csv",
                "url" => mock_csv_url
              }
            ]
          }
        }.to_json

        api_response = double(code: 200, body: api_json)
        expect(HTTParty).to receive(:get)
          .with(content_api_url, hash_including(headers: hash_including("Cache-Control")))
          .and_return(api_response)

        csv_response = double(code: 200)
        expect(HTTParty).to receive(:get)
          .with(mock_csv_url, stream_body: true)
          .and_yield("row1,row2")
          .and_return(csv_response)

        result = SponsorCsvDownloader.call
        expect(result[:url]).to eq(mock_csv_url)
        expect(result[:filename]).to eq("Worker.csv")
        expect(File.exist?(result[:path])).to be true

        File.delete(result[:path]) if File.exist?(result[:path])
      end
    end

    context "when Content API fails" do
      it "raises an error" do
        api_response = double(code: 500, body: "")
        expect(HTTParty).to receive(:get)
          .with(content_api_url, hash_including(headers: hash_including("Cache-Control")))
          .and_return(api_response)

        expect { SponsorCsvDownloader.call }.to raise_error(RuntimeError, /GOV.UK Content API returned HTTP 500/)
      end
    end
  end
end

