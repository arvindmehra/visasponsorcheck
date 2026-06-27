class ChangeCompaniesIndexToGin < ActiveRecord::Migration[8.1]
  def change
    remove_index :companies, :name_normalised, name: :index_companies_on_name_normalised
    add_index :companies, :name_normalised, name: :index_companies_on_name_normalised, using: :gin, opclass: :gin_trgm_ops
  end
end

