class AddEnrichedAtToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :enriched_at, :datetime
  end
end
