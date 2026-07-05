class CreateSponsorLicences < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_licences do |t|
      t.references :company, null: false, foreign_key: true
      t.text :organisation_name, null: false
      t.text :licence_type, null: false
      t.text :rating, null: false
      t.text :route, null: false
      t.text :status, null: false
      t.datetime :first_seen_at, null: false
      t.datetime :last_seen_at, null: false

      t.timestamps
    end

    add_index :sponsor_licences, [ :company_id, :route ], unique: true
  end
end
