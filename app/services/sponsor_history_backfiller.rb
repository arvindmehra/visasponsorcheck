# Orchestrates the Wayback Machine backfill: walks every distinct archived
# register version chronologically, diffs each against the one before it,
# and for any (company, route) pair we already track, records a
# SponsorLicenceHistoricalObservation and — for "added" events only — pulls
# SponsorLicence#first_seen_at earlier if the archive evidence predates it.
#
# Deliberately conservative about what it touches:
#   * Only companies already in our `companies` table are considered — a
#     company that existed historically but was gone before we started
#     tracking has nothing for this to attach a date to.
#   * first_seen_at only ever moves earlier, never later — we're refining
#     a lower bound with better evidence, not overwriting live-sync data.
#   * "removed" events are recorded as observations for the historical
#     record, but deliberately do NOT touch SponsorLicence#suspended_at —
#     a route that appears removed in a 2022 archive snapshot and is
#     active again today isn't "currently suspended", so writing to that
#     column here would misrepresent current status.
#
# This is a one-off, manually-run backfill (see lib/tasks/sponsor_history_backfill.rake)
# — not part of the daily sync — so it logs verbosely and paces its own
# requests rather than trying to run fast.
class SponsorHistoryBackfiller
  REQUEST_DELAY_SECONDS = 1.5

  def self.call(from: SponsorHistorySnapshotFinder::CSV_ERA_START, to: nil, logger: Rails.logger)
    new(from: from, to: to, logger: logger).call
  end

  def initialize(from:, to:, logger:)
    @from = from
    @to = to
    @logger = logger
    @stats = { versions_processed: 0, versions_skipped: 0, observations_created: 0, first_seen_at_updated: 0 }
  end

  def call
    versions = SponsorHistorySnapshotFinder.call(from: @from, to: @to)
    @logger.info("SponsorHistoryBackfiller: found #{versions.size} distinct register versions from #{@from} onward")

    previous_rows = nil
    previous_timestamp = nil

    versions.each_with_index do |version, index|
      @logger.info("SponsorHistoryBackfiller: [#{index + 1}/#{versions.size}] #{version[:wayback_timestamp]}")

      current_rows = parse_version(version)
      unless current_rows
        @stats[:versions_skipped] += 1
        pace_requests
        next
      end

      if previous_rows
        diff = SponsorHistoryDiffer.call(previous_rows: previous_rows, current_rows: current_rows)
        record_diff(diff, version, previous_timestamp)
      end

      previous_rows = current_rows
      previous_timestamp = version[:wayback_timestamp]
      @stats[:versions_processed] += 1

      pace_requests
    end

    @logger.info("SponsorHistoryBackfiller: done — #{@stats}")
    @stats
  end

  private

  # Real pacing only matters against the live archive.org API; skip it under
  # test so the spec suite doesn't pay 1.5s per snapshot for no reason.
  def pace_requests
    sleep REQUEST_DELAY_SECONDS unless Rails.env.test?
  end

  def parse_version(version)
    csv_path = WaybackClient.fetch(timestamp: version[:wayback_timestamp], original_url: version[:csv_url])
    rows = SponsorCsvParser.call(csv_path)
    File.delete(csv_path) if File.exist?(csv_path)
    rows
  rescue => e
    @logger.warn("SponsorHistoryBackfiller: skipping #{version[:wayback_timestamp]} (#{e.message})")
    nil
  end

  def record_diff(diff, version, previous_timestamp)
    occurred_before = parse_wayback_timestamp(version[:wayback_timestamp])
    occurred_after = previous_timestamp ? parse_wayback_timestamp(previous_timestamp) : nil

    diff.added.each { |name, route| record_observation(name, route, "added", version, occurred_before, occurred_after) }
    diff.removed.each { |name, route| record_observation(name, route, "removed", version, occurred_before, occurred_after) }
  end

  def record_observation(name_normalised, route, event_type, version, occurred_before, occurred_after)
    company = Company.find_by(name_normalised: name_normalised)
    return unless company

    observation = SponsorLicenceHistoricalObservation.find_or_initialize_by(
      company: company,
      route: route,
      event_type: event_type,
      wayback_timestamp: version[:wayback_timestamp]
    )
    return if observation.persisted?

    observation.assign_attributes(
      occurred_before: occurred_before,
      occurred_after: occurred_after,
      source_csv_url: version[:csv_url]
    )
    observation.save!
    @stats[:observations_created] += 1

    pull_first_seen_at_earlier(company, route, occurred_before) if event_type == "added"
  end

  def pull_first_seen_at_earlier(company, route, occurred_before)
    licence = company.sponsor_licences.find_by(route: route)
    return unless licence
    return if licence.first_seen_at.present? && licence.first_seen_at <= occurred_before

    licence.update_column(:first_seen_at, occurred_before)
    @stats[:first_seen_at_updated] += 1
  end

  def parse_wayback_timestamp(timestamp)
    Time.strptime(timestamp, "%Y%m%d%H%M%S").utc
  end
end
