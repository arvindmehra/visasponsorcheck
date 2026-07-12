FactoryBot.define do
  factory :search_log do
    sequence(:query) { |n| "company #{n}" }
    results_count { 1 }
  end
end
