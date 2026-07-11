class CreateCompanyProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :company_profiles do |t|
      t.references :company, null: false, foreign_key: true, index: { unique: true }
      t.string :company_status
      t.string :company_type
      t.date :date_of_creation
      t.integer :sic_code
      t.string :sic_code_description
      t.datetime :enriched_at

      t.timestamps
    end

    add_index :company_profiles, :sic_code
  end
end
