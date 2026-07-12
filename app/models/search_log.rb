class SearchLog < ApplicationRecord
  validates :query, presence: true
  validates :results_count, presence: true, numericality: { greater_than_or_equal_to: 0 }
end
