class CreateSponsorImportLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_import_logs do |t|
      t.text :source_url, null: false
      t.text :csv_filename
      t.text :status, null: false, default: "pending"
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :total_rows, default: 0, null: false
      t.integer :new_licences, default: 0, null: false
      t.integer :updated_licences, default: 0, null: false
      t.integer :removed_licences, default: 0, null: false
      t.text :error_message

      t.timestamps
    end
  end
end
