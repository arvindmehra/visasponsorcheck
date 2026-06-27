class CreateSponsorChangeEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :sponsor_change_events do |t|
      t.references :company, null: false, foreign_key: true
      t.references :sponsor_import_log, null: false, foreign_key: true
      t.text :event_type, null: false
      t.text :field_name
      t.text :old_value
      t.text :new_value
      t.datetime :occurred_at, null: false

      t.timestamps
    end
  end
end
