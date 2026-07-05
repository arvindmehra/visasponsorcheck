class AddSeoIndexes < ActiveRecord::Migration[8.1]
  def change
    # Add town_normalised for reliable city slug-based routing
    add_column :companies, :town_normalised, :text

    # Populate town_normalised from existing town data
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE companies
          SET town_normalised = LOWER(TRIM(town))
          WHERE town IS NOT NULL AND TRIM(town) != '' AND LOWER(TRIM(town)) != 'null'
        SQL
      end
    end

    # Indexes on companies for filtering by city
    add_index :companies, :town,            name: "index_companies_on_town"
    add_index :companies, :town_normalised, name: "index_companies_on_town_normalised"

    # Indexes on sponsor_licences for all filter columns used in directory pages
    add_index :sponsor_licences, :status,       name: "index_sponsor_licences_on_status"
    add_index :sponsor_licences, :rating,       name: "index_sponsor_licences_on_rating"
    add_index :sponsor_licences, :route,        name: "index_sponsor_licences_on_route"
    add_index :sponsor_licences, :licence_type, name: "index_sponsor_licences_on_licence_type"
  end
end
