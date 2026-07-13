class SponsorChangeEvent < ApplicationRecord
  # -----------------------------------------------------------------------
  # Constants
  # -----------------------------------------------------------------------

  # Event types emitted by the importer
  EVENT_TYPES = %w[
    added
    removed
    rating_changed
    status_changed
    route_changed
    licence_type_changed
  ].freeze

  # -----------------------------------------------------------------------
  # Associations
  # -----------------------------------------------------------------------

  belongs_to :company
  belongs_to :sponsor_import_log

  # -----------------------------------------------------------------------
  # Callbacks
  # -----------------------------------------------------------------------

  # Safety net: ensures the company's stale licence(s) actually end up
  # "removed" once we've recorded that they were. Runs after commit so it
  # never fires for an event that gets rolled back.
  after_create_commit :enqueue_removal_job, if: -> { event_type == "removed" }

  # -----------------------------------------------------------------------
  # Validations
  # -----------------------------------------------------------------------

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
  validates :occurred_at, presence: true

  # -----------------------------------------------------------------------
  # Scopes
  # -----------------------------------------------------------------------

  scope :recent,       -> { order(occurred_at: :desc) }
  scope :for_company,  ->(company) { where(company: company) }
  scope :additions,    -> { where(event_type: "added") }
  scope :removals,     -> { where(event_type: "removed") }
  scope :changes_only, -> { where.not(event_type: %w[added removed]) }

  # -----------------------------------------------------------------------
  # Display helpers
  # -----------------------------------------------------------------------

  def human_description
    case event_type
    when "added"
      "Added as a licensed sponsor"
    when "removed"
      "Removed from the sponsor register"
    when "rating_changed"
      "Rating changed from #{old_value.inspect} to #{new_value.inspect}"
    when "status_changed"
      "Status changed from #{old_value} to #{new_value}"
    when "route_changed"
      "Route changed from #{old_value.inspect} to #{new_value.inspect}"
    when "licence_type_changed"
      "Licence type changed from #{old_value.inspect} to #{new_value.inspect}"
    else
      "#{field_name} changed from #{old_value.inspect} to #{new_value.inspect}"
    end
  end

  def icon
    case event_type
    when "added"    then "✅"
    when "removed"  then "❌"
    else                 "🔄"
    end
  end

  private

  def enqueue_removal_job
    SponsorLicenceRemovalJob.perform_later(id)
  end
end
