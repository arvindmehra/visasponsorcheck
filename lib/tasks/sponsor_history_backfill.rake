# Usage:
#   bin/rails sponsors:backfill_history                          # full Dec 2021 -> now backfill
#   FROM=20220101 TO=20221231 bin/rails sponsors:backfill_history # bounded range (YYYYMMDD)
#
# One-off, manually-run backfill — NOT part of the daily sync. Reconstructs
# historical sponsor_licences.first_seen_at values and
# SponsorLicenceHistoricalObservation records from archived (Wayback
# Machine) copies of the GOV.UK register CSV, back to when the register
# switched from PDF to CSV (~Dec 2021 — see SponsorHistorySnapshotFinder).
#
# Paces its own requests against archive.org (~1.5s between fetches) and can
# take a while for the full range — this is expected, let it run.
#
# In Docker: docker exec visasponsoruk-web bin/rails sponsors:backfill_history
namespace :sponsors do
  desc "Backfill sponsor_licences.first_seen_at and historical observations from Wayback Machine archives"
  task backfill_history: :environment do
    from = ENV["FROM"] || SponsorHistorySnapshotFinder::CSV_ERA_START
    to = ENV["TO"]

    stats = SponsorHistoryBackfiller.call(from: from, to: to, logger: Rails.logger)

    puts "Versions processed: #{stats[:versions_processed]}"
    puts "Versions skipped (fetch/parse errors): #{stats[:versions_skipped]}"
    puts "Historical observations created: #{stats[:observations_created]}"
    puts "sponsor_licences.first_seen_at pulled earlier: #{stats[:first_seen_at_updated]}"
  end
end
