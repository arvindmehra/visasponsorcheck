# A reconstructed historical event, derived from diffing two archived
# (Wayback Machine) snapshots of the GOV.UK register CSV — NOT a live
# observation like SponsorChangeEvent. Deliberately kept as a separate model
# so a one-off backfill run can never contaminate the live daily-sync
# statistics (homepage "Today's Register" counts, etc.).
#
# occurred_before/occurred_after bound the change to a window, not a single
# day — a Wayback capture is a snapshot, not continuous monitoring, so the
# actual change could have happened any time between the previous capture
# (occurred_after) and the one where it was first/last observed
# (occurred_before). occurred_after is nil when there's no earlier capture
# in the backfill dataset to bound it.
class SponsorLicenceHistoricalObservation < ApplicationRecord
  EVENT_TYPES = %w[added removed].freeze

  belongs_to :company

  validates :route, presence: true
  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_before, presence: true
  validates :wayback_timestamp, presence: true
  validates :source_csv_url, presence: true

  scope :additions, -> { where(event_type: "added") }
  scope :removals, -> { where(event_type: "removed") }

  # The Wayback Machine URL this observation's evidence can be viewed at —
  # always reconstructible from the stored timestamp + source URL, so a
  # reconstructed date can be independently checked rather than just trusted.
  def wayback_url
    "https://web.archive.org/web/#{wayback_timestamp}/#{source_csv_url}"
  end

  # Human-friendly description of the bounded date window, since we never
  # know the exact day — only "sometime in this range".
  def date_range_description
    if occurred_after.present?
      "between #{occurred_after.strftime('%-d %b %Y')} and #{occurred_before.strftime('%-d %b %Y')}"
    else
      "no later than #{occurred_before.strftime('%-d %b %Y')}"
    end
  end
end
