class SponsorImportLog < ApplicationRecord
  # -----------------------------------------------------------------------
  # Constants
  # -----------------------------------------------------------------------

  STATUSES = %w[pending running done failed].freeze

  # -----------------------------------------------------------------------
  # Associations
  # -----------------------------------------------------------------------

  has_many :sponsor_change_events, foreign_key: :sponsor_import_log_id,
                                   dependent: :nullify

  # -----------------------------------------------------------------------
  # Validations
  # -----------------------------------------------------------------------

  validates :source_url, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  # -----------------------------------------------------------------------
  # Scopes
  # -----------------------------------------------------------------------

  scope :recent, -> { order(created_at: :desc) }
  scope :done,   -> { where(status: "done") }
  scope :failed, -> { where(status: "failed") }

  # -----------------------------------------------------------------------
  # State transition helpers
  # -----------------------------------------------------------------------

  def start!
    update!(status: "running", started_at: Time.current)
  end

  def finish!(stats = {})
    update!(
      status: "done",
      completed_at: Time.current,
      **stats.slice(:total_rows, :new_licences, :updated_licences, :removed_licences)
    )
  end

  def fail!(message)
    update!(status: "failed", error_message: message, completed_at: Time.current)
  end

  # -----------------------------------------------------------------------
  # Display helpers
  # -----------------------------------------------------------------------

  def duration
    return nil unless started_at && completed_at

    completed_at - started_at
  end

  def summary
    "#{total_rows} rows — #{new_licences} new, #{updated_licences} updated, #{removed_licences} removed"
  end
end
