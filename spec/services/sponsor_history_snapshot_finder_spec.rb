require "rails_helper"

RSpec.describe SponsorHistorySnapshotFinder do
  describe ".call" do
    def html_with_csv_link(href)
      %(<html><body><a href="#{href}">Download</a></body></html>)
    end

    def stub_fetch(timestamp, content)
      path = Tempfile.new([ "snap", ".html" ]).path
      File.write(path, content)
      allow(WaybackClient).to receive(:fetch).with(timestamp: timestamp, original_url: anything).and_return(path)
    end

    it "extracts the CSV link from each page snapshot, stripping the Wayback proxy prefix" do
      allow(WaybackClient).to receive(:list_snapshots).and_return([
        { timestamp: "20220112122447", url: described_class::REGISTER_PAGE_URL }
      ])
      stub_fetch("20220112122447", html_with_csv_link("/web/20220112122447/https://assets.publishing.service.gov.uk/file1.csv"))

      result = described_class.call

      expect(result).to eq([ { csv_url: "https://assets.publishing.service.gov.uk/file1.csv", wayback_timestamp: "20220112122447" } ])
    end

    it "strips the absolute web.archive.org prefix form too" do
      allow(WaybackClient).to receive(:list_snapshots).and_return([
        { timestamp: "20190723174232", url: described_class::REGISTER_PAGE_URL }
      ])
      stub_fetch("20190723174232", html_with_csv_link("https://web.archive.org/web/20190723174232/https://assets.publishing.service.gov.uk/file2.csv"))

      result = described_class.call

      expect(result.first[:csv_url]).to eq("https://assets.publishing.service.gov.uk/file2.csv")
    end

    it "collapses consecutive captures that point at the same underlying CSV into one entry" do
      allow(WaybackClient).to receive(:list_snapshots).and_return([
        { timestamp: "20220112122447", url: described_class::REGISTER_PAGE_URL },
        { timestamp: "20220119143720", url: described_class::REGISTER_PAGE_URL },
        { timestamp: "20220204153920", url: described_class::REGISTER_PAGE_URL }
      ])
      stub_fetch("20220112122447", html_with_csv_link("/web/20220112122447/https://assets.publishing.service.gov.uk/same.csv"))
      stub_fetch("20220119143720", html_with_csv_link("/web/20220119143720/https://assets.publishing.service.gov.uk/same.csv"))
      stub_fetch("20220204153920", html_with_csv_link("/web/20220204153920/https://assets.publishing.service.gov.uk/different.csv"))

      result = described_class.call

      expect(result).to eq([
        { csv_url: "https://assets.publishing.service.gov.uk/same.csv", wayback_timestamp: "20220112122447" },
        { csv_url: "https://assets.publishing.service.gov.uk/different.csv", wayback_timestamp: "20220204153920" }
      ])
    end

    it "skips a snapshot with no CSV link at all, without raising" do
      allow(WaybackClient).to receive(:list_snapshots).and_return([
        { timestamp: "20160410040101", url: described_class::REGISTER_PAGE_URL },
        { timestamp: "20220112122447", url: described_class::REGISTER_PAGE_URL }
      ])
      stub_fetch("20160410040101", "<html><body><a href=\"/web/20160410040101/https://gov.uk/file.pdf\">PDF</a></body></html>")
      stub_fetch("20220112122447", html_with_csv_link("/web/20220112122447/https://assets.publishing.service.gov.uk/file1.csv"))

      result = described_class.call

      expect(result.size).to eq(1)
      expect(result.first[:wayback_timestamp]).to eq("20220112122447")
    end

    it "skips a snapshot that raises while fetching, without aborting the whole run" do
      allow(WaybackClient).to receive(:list_snapshots).and_return([
        { timestamp: "20220112122447", url: described_class::REGISTER_PAGE_URL },
        { timestamp: "20220204153920", url: described_class::REGISTER_PAGE_URL }
      ])
      allow(WaybackClient).to receive(:fetch).with(timestamp: "20220112122447", original_url: anything).and_raise(StandardError, "timeout")
      stub_fetch("20220204153920", html_with_csv_link("/web/20220204153920/https://assets.publishing.service.gov.uk/file1.csv"))

      result = described_class.call

      expect(result.size).to eq(1)
      expect(result.first[:wayback_timestamp]).to eq("20220204153920")
    end
  end
end
