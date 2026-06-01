class CreateCompanies < ActiveRecord::Migration[8.1]
  def change
    create_table :companies do |t|
      t.text :name, null: false
      t.text :name_normalised, null: false
      t.text :slug, null: false
      t.text :town
      t.text :county

      t.timestamps
    end

    add_index :companies, :slug, unique: true
    add_index :companies, :name_normalised, opclass: :gist_trgm_ops, using: :gist
  end
end
