class BlogIngestionLog < ApplicationRecord
  validates :source_url, presence: true, uniqueness: true

  def self.already_processed?(url)
    exists?(source_url: url)
  end

  def self.mark_processed!(url, title: nil)
    create!(source_url: url, title: title, status: "processed", processed_at: Time.current)
  end
end
