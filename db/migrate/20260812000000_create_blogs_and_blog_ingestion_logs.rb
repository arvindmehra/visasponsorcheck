class CreateBlogsAndBlogIngestionLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :blogs do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.string :category, null: false
      t.text :meta_description, null: false
      t.jsonb :key_takeaways, default: []
      t.text :content_html, null: false
      t.string :featured_image_url
      t.integer :quality_score, default: 0, null: false
      t.string :status, default: "pending_review", null: false
      t.string :source_url
      t.datetime :published_at

      t.timestamps
    end

    add_index :blogs, :slug, unique: true
    add_index :blogs, :status
    add_index :blogs, :category
    add_index :blogs, :published_at

    create_table :blog_ingestion_logs do |t|
      t.string :source_url, null: false
      t.string :title
      t.string :status, default: "processed", null: false
      t.datetime :processed_at

      t.timestamps
    end

    add_index :blog_ingestion_logs, :source_url, unique: true
  end
end
