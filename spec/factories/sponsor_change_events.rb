FactoryBot.define do
  factory :sponsor_change_event do
    association :company
    association :sponsor_import_log
    event_type  { "added" }
    field_name  { nil }
    old_value   { nil }
    new_value   { nil }
    occurred_at { Time.current }

    trait :removed do
      event_type { "removed" }
    end

    trait :rating_changed do
      event_type { "rating_changed" }
      field_name { "rating" }
      old_value  { "B" }
      new_value  { "A" }
    end

    trait :status_changed do
      event_type { "status_changed" }
      field_name { "status" }
      old_value  { "active" }
      new_value  { "removed" }
    end
  end
end
