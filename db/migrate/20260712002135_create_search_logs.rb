class CreateSearchLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :search_logs do |t|
      t.string :query, null: false
      t.integer :results_count, null: false, default: 0

      t.timestamps
    end

    add_index :search_logs, :query
  end
end
