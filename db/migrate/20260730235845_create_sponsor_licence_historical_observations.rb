class CreateSponsorLicenceHistoricalObservations < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_licence_historical_observations do |t|
      t.references :company, null: false, foreign_key: true

      t.text :route, null: false
      t.text :event_type, null: false # "added" or "removed"

      # A Wayback capture is a snapshot, not continuous monitoring — a change
      # is only ever known to have happened *between* two captures. These
      # bound that window; occurred_after is null when there's no earlier
      # capture in our dataset to bound it (unbounded on the low end).
      t.datetime :occurred_before, null: false
      t.datetime :occurred_after

      # Provenance — always traceable back to the actual archive.org capture
      # this observation was derived from, so a reconstructed date can be
      # independently verified rather than just trusted blindly.
      t.string :wayback_timestamp, null: false
      t.text :source_csv_url, null: false

      t.timestamps
    end

    # Prevents duplicate rows if the backfill rake task is re-run (e.g. after
    # a partial failure) — same company/route/event/capture is the same
    # observation, not a new one.
    add_index :sponsor_licence_historical_observations,
              [ :company_id, :route, :event_type, :wayback_timestamp ],
              unique: true,
              name: "index_sponsor_licence_historical_observations_uniqueness"
  end
end
