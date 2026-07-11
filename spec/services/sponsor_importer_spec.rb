require "rails_helper"
require "tempfile"

RSpec.describe SponsorImporter do
  let(:temp_csv) { Tempfile.new([ "test_import", ".csv" ]) }

  before do
    # Stub the downloader so it returns our temp file path
    allow(SponsorCsvDownloader).to receive(:call).and_return({
      path: temp_csv.path,
      url: "https://example.com/sponsors.csv",
      filename: "sponsors.csv"
    })
  end

  after do
    temp_csv.close
    temp_csv.unlink
  end

  describe ".call" do
    it "imports new companies and licences and handles events" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
        "Bossmans Retail Ltd",Abergavenny,,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.to change(Company, :count).by(2)
       .and change(SponsorLicence, :count).by(2)
       .and change(SponsorChangeEvent, :count).by(2)

      # Check database records
      company = Company.find_by(name_normalised: "boltwhiz limited")
      expect(company).to be_present
      expect(company.town).to eq("Dunfermline")
      expect(company.county).to eq("Scotland")
      expect(company.slug).to eq("boltwhiz-limited")

      licence = company.sponsor_licences.first
      expect(licence.organisation_name).to eq("BOLTWHIZ LIMITED")
      expect(licence.licence_type).to eq("Worker")
      expect(licence.rating).to eq("A")
      expect(licence.route).to eq("Skilled Worker")
      expect(licence.status).to eq("active")

      event = company.sponsor_change_events.first
      expect(event.event_type).to eq("added")

      log = SponsorImportLog.last
      expect(log.status).to eq("done")
      expect(log.total_rows).to eq(2)
      expect(log.new_licences).to eq(2)
      expect(log.updated_licences).to eq(0)
      expect(log.removed_licences).to eq(0)
    end

    it "enqueues a CompanyEnrichmentJob for each newly created company" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
        "Bossmans Retail Ltd",Abergavenny,,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.to have_enqueued_job(CompanyEnrichmentJob).exactly(2).times

      # Re-importing the same companies should not enqueue new enrichment jobs
      temp_csv.truncate(0)
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (B rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.not_to have_enqueued_job(CompanyEnrichmentJob)
    end

    it "is idempotent on consecutive runs with the same data" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      # Run 1
      SponsorImporter.call

      # Run 2
      expect {
        SponsorImporter.call
      }.to_not change(Company, :count)

      expect(SponsorLicence.count).to eq(1)
      expect(SponsorChangeEvent.count).to eq(1) # Only the original "added" event

      log = SponsorImportLog.last
      expect(log.new_licences).to eq(0)
      expect(log.updated_licences).to eq(0)
      expect(log.removed_licences).to eq(0)
    end

    it "records events when a rating or type changes" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      SponsorImporter.call

      # Update rating in next import CSV
      temp_csv.truncate(0)
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (B rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.to change(SponsorChangeEvent, :count).by(1)

      licence = SponsorLicence.first
      expect(licence.rating).to eq("B")

      event = SponsorChangeEvent.last
      expect(event.event_type).to eq("rating_changed")
      expect(event.old_value).to eq("A")
      expect(event.new_value).to eq("B")
    end

    it "marks active licences missing from the CSV as removed" do
      # Run 1: Import two sponsors
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
        "Bossmans Retail Ltd",Abergavenny,,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      SponsorImporter.call

      # Run 2: Import only one of them
      temp_csv.truncate(0)
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.to change(SponsorChangeEvent, :count).by(1)

      removed_licence = SponsorLicence.find_by(organisation_name: "Bossmans Retail Ltd")
      expect(removed_licence.status).to eq("removed")

      event = SponsorChangeEvent.last
      expect(event.company).to eq(removed_licence.company)
      expect(event.event_type).to eq("removed")
    end

    it "skips invalid rows, processes valid ones, and writes an error CSV" do
      temp_csv.write(<<~CSV)
        Organisation Name,Town/City,County,Type & Rating,Route
        "BOLTWHIZ LIMITED",Dunfermline,Scotland,Worker (A rating),Skilled Worker
        "INVALID LIMITED",Dunfermline,Scotland,Invalid Type (A rating),Skilled Worker
      CSV
      temp_csv.rewind

      expect {
        SponsorImporter.call
      }.to change(Company, :count).by(1)
       .and change(SponsorLicence, :count).by(1)

      log = SponsorImportLog.last
      expect(log.status).to eq("done")
      expect(log.total_rows).to eq(2)
      expect(log.new_licences).to eq(1)
      expect(log.error_message).to include("Import completed with 1 row failures. Error log saved at:")

      # Verify error CSV file was created
      error_file_path = log.error_message.split("saved at: ").last
      expect(File.exist?(error_file_path)).to be true

      csv_content = CSV.read(error_file_path)
      expect(csv_content.size).to eq(2) # Header + 1 error row
      expect(csv_content[1][0]).to eq("INVALID LIMITED")
      expect(csv_content[1][4]).to include("Validation failed: Licence type is not included in the list")

      # Clean up error file
      File.delete(error_file_path) if File.exist?(error_file_path)
    end
  end
end
