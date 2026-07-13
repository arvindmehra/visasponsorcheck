FactoryBot.define do
  factory :sponsor_licence do
    association :company
    sequence(:organisation_name) { |n| "Organisation #{n} Ltd" }
    licence_type { "Worker" }
    rating       { "A" }
    route        { "Skilled Worker" }
    status       { "active" }
    first_seen_at { 1.week.ago }
    last_seen_at  { Time.current }

    trait :temporary_worker do
      licence_type { "Temporary Worker" }
      route        { "Seasonal Worker" }
    end

    trait :rating_b do
      rating { "B" }
    end

    trait :provisional do
      rating { "Provisional" }
      route  { "Global Business Mobility: UK Expansion Worker" }
    end

    trait :removed do
      status { "removed" }
    end
  end
end
