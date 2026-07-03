class AddEnrichmentFieldsToCompanies < ActiveRecord::Migration[8.1]
  def change
    add_column :companies, :company_number, :string
    add_index :companies, :company_number
    add_column :companies, :registered_office_address, :text
    add_column :companies, :website_url, :string
    add_column :companies, :linkedin_url, :string
  end
end
