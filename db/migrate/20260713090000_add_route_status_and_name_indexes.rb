class AddRouteStatusAndNameIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    # Supports Company.by_route's WHERE sponsor_licences.route = ? AND status = ?
    add_index :sponsor_licences, [ :route, :status ], algorithm: :concurrently

    # Supports ORDER BY companies.name, used by nearly every listing scope
    # (by_city, by_sector, by_route, a_rated, revoked). Only name_normalised
    # had an index (trigram, for fuzzy search) — nothing supported a plain sort.
    add_index :companies, :name, algorithm: :concurrently
  end
end
