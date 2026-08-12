class Blog < ApplicationRecord
  CATEGORIES = [
    "Immigration News",
    "Sponsor Licence",
    "Compliance",
    "Visa",
    "WorkPermitCloud Tools",
    "Others"
  ].freeze

  STATUSES = [
    "pending_review",
    "published",
    "archived"
  ].freeze

  validates :title, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :meta_description, presence: true
  validates :content_html, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validates :quality_score, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  scope :published, -> { where(status: "published").where("published_at <= ?", Time.current).order(published_at: :desc) }
  scope :pending_review, -> { where(status: "pending_review").order(created_at: :desc) }
  scope :by_category, ->(cat) { where(category: cat) if cat.present? && cat != "All Categories" }
  scope :search_by_query, ->(q) {
    if q.present?
      where("title ILIKE :q OR content_html ILIKE :q OR meta_description ILIKE :q", q: "%#{q}%")
    end
  }

  before_validation :generate_slug, on: :create
  before_save :set_published_at, if: -> { status_changed? && status == "published" }

  def to_param
    slug
  end

  private

  def generate_slug
    return if slug.present? || title.blank?

    base_slug = title.parameterize
    candidate = base_slug
    count = 1
    while Blog.exists?(slug: candidate)
      candidate = "#{base_slug}-#{count}"
      count += 1
    end
    self.slug = candidate
  end

  def set_published_at
    self.published_at ||= Time.current
  end
end
