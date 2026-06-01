FactoryBot.define do
  factory :sponsor_import_log do
    source_url   { "https://assets.publishing.service.gov.uk/sponsor-register.csv" }
    csv_filename { "2026-06-01_-_Worker_and_Temporary_Worker.csv" }
    status       { "done" }
    total_rows   { 100 }
    new_licences { 5 }
    updated_licences { 2 }
    removed_licences { 1 }
    started_at   { 10.minutes.ago }
    completed_at { 1.minute.ago }

    trait :running do
      status       { "running" }
      started_at   { 1.minute.ago }
      completed_at { nil }
    end

    trait :failed do
      status        { "failed" }
      error_message { "Connection timeout" }
      completed_at  { 1.minute.ago }
    end
  end
end
