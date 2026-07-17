class RemoveUnwantedIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Redundant: index_sponsor_licences_on_company_id_and_route (unique,
    # [company_id, route]) already covers any WHERE company_id = ? lookup
    # via its leading column — a composite index's prefix serves standalone
    # queries on that prefix just as well as a dedicated single-column index.
    remove_index :sponsor_licences, :company_id, algorithm: :concurrently

    # Redundant for the same reason: index_sponsor_licences_on_route_and_status
    # ([route, status]) already covers any WHERE route = ? lookup.
    remove_index :sponsor_licences, :route, algorithm: :concurrently

    # Unused: every query in the app filters on town_normalised; raw `town`
    # is never used in a WHERE/find_by anywhere in the codebase.
    remove_index :companies, :town, algorithm: :concurrently

    # Unused: only backs SponsorLicence.workers/.temporary, and neither
    # scope is called anywhere in the app — dead index behind dead scopes.
    remove_index :sponsor_licences, :licence_type, algorithm: :concurrently
  end
end
