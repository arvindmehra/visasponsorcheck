class SponsorLicenceRemovalJob < ApplicationJob
  queue_as :default

  def perform(sponsor_change_event_id)
    event = SponsorChangeEvent.find_by(id: sponsor_change_event_id)
    return unless event&.event_type == "removed"

    company = Company.find_by(id: event.company_id)
    return unless company

    # A "removed" event doesn't record which route it was for, so only mark
    # licences unseen as of that event's sync as removed — this keeps a
    # different route that's still genuinely active on the same company
    # from being wrongly revoked.
    company.sponsor_licences.active.where("last_seen_at < ?", event.occurred_at).find_each do |licence|
      licence.update!(status: "removed")
    end
  end
end
