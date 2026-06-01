FactoryBot.define do
  factory :company do
    sequence(:name) { |n| "Company #{n} Limited" }
    town  { "London" }
    county { nil }
  end
end
