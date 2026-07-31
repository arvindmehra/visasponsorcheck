require "rails_helper"

RSpec.describe SponsorHistoryBackfiller do
  # Alpha Ltd already exists in our system; Beta Ltd never does — used to
  # prove unmatched historical companies are skipped, not crashed on.
  let!(:alpha) { create(:company, name: "Alpha Ltd") }
  let!(:alpha_licence) do
    create(:sponsor_licence, company: alpha, route: "Skilled Worker", status: "active", first_seen_at: Time.zone.parse("2024-01-01"))
  end

  def csv_file(rows)
    header = "Organisation Name,Town/City,County,Type & Rating,Route\n"
    body = rows.map { |name, route| %("#{name}",London,,Worker (A rating),#{route}) }.join("\n")
    path = Tempfile.new([ "snapshot", ".csv" ]).path
    File.write(path, header + body)
    path
  end

  # T1: nobody yet. T2: Alpha + Beta appear. T3: both disappear again.
  let(:t1) { { wayback_timestamp: "20220101000000", csv_url: "https://assets.publishing.service.gov.uk/v1.csv" } }
  let(:t2) { { wayback_timestamp: "20220201000000", csv_url: "https://assets.publishing.service.gov.uk/v2.csv" } }
  let(:t3) { { wayback_timestamp: "20220301000000", csv_url: "https://assets.publishing.service.gov.uk/v3.csv" } }

  before do
    allow(SponsorHistorySnapshotFinder).to receive(:call).and_return([ t1, t2, t3 ])
    allow(WaybackClient).to receive(:fetch).with(timestamp: t1[:wayback_timestamp], original_url: t1[:csv_url]).and_return(csv_file([]))
    allow(WaybackClient).to receive(:fetch).with(timestamp: t2[:wayback_timestamp], original_url: t2[:csv_url])
      .and_return(csv_file([ [ "Alpha Ltd", "Skilled Worker" ], [ "Beta Ltd", "Skilled Worker" ] ]))
    allow(WaybackClient).to receive(:fetch).with(timestamp: t3[:wayback_timestamp], original_url: t3[:csv_url]).and_return(csv_file([]))
  end

  it "creates an 'added' observation for a company we track, at the snapshot where it first appeared" do
    described_class.call(logger: Logger.new(File::NULL))

    observation = SponsorLicenceHistoricalObservation.find_by(company: alpha, event_type: "added")
    expect(observation).to be_present
    expect(observation.route).to eq("Skilled Worker")
    expect(observation.occurred_before).to eq(Time.strptime(t2[:wayback_timestamp], "%Y%m%d%H%M%S").utc)
    expect(observation.occurred_after).to eq(Time.strptime(t1[:wayback_timestamp], "%Y%m%d%H%M%S").utc)
  end

  it "pulls sponsor_licences.first_seen_at earlier when archive evidence predates it" do
    expect { described_class.call(logger: Logger.new(File::NULL)) }
      .to change { alpha_licence.reload.first_seen_at }
      .from(Time.zone.parse("2024-01-01"))
      .to(Time.strptime(t2[:wayback_timestamp], "%Y%m%d%H%M%S").utc)
  end

  it "creates a 'removed' observation for the later snapshot, without touching first_seen_at again" do
    described_class.call(logger: Logger.new(File::NULL))

    removed_observation = SponsorLicenceHistoricalObservation.find_by(company: alpha, event_type: "removed")
    expect(removed_observation).to be_present
    expect(removed_observation.occurred_before).to eq(Time.strptime(t3[:wayback_timestamp], "%Y%m%d%H%M%S").utc)

    expect(alpha_licence.reload.first_seen_at).to eq(Time.strptime(t2[:wayback_timestamp], "%Y%m%d%H%M%S").utc)
  end

  it "does not create observations or raise for a historical company we've never tracked" do
    expect { described_class.call(logger: Logger.new(File::NULL)) }.not_to raise_error

    expect(SponsorLicenceHistoricalObservation.where(route: "Skilled Worker").map(&:company)).to all(eq(alpha))
  end

  it "does not move first_seen_at later, even if archive evidence is more recent than what we already have" do
    alpha_licence.update!(first_seen_at: Time.zone.parse("2020-01-01")) # earlier than any archive snapshot here

    expect { described_class.call(logger: Logger.new(File::NULL)) }
      .not_to change { alpha_licence.reload.first_seen_at }
  end

  it "is idempotent — running it twice does not duplicate observations" do
    described_class.call(logger: Logger.new(File::NULL))
    first_run_count = SponsorLicenceHistoricalObservation.count

    described_class.call(logger: Logger.new(File::NULL))

    expect(SponsorLicenceHistoricalObservation.count).to eq(first_run_count)
  end

  it "skips a version that fails to fetch/parse and continues with the rest" do
    allow(WaybackClient).to receive(:fetch).with(timestamp: t2[:wayback_timestamp], original_url: t2[:csv_url]).and_raise(StandardError, "network error")

    stats = described_class.call(logger: Logger.new(File::NULL))

    expect(stats[:versions_skipped]).to eq(1)
    # T1 -> T3 diff still runs (both empty), so no crash and no false observations
    expect(SponsorLicenceHistoricalObservation.count).to eq(0)
  end
end
