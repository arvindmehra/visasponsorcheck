FactoryBot.define do
  factory :sponsor_licence_historical_observation do
    association :company
    route { "Skilled Worker" }
    event_type { "added" }
    occurred_before { 2.years.ago }
    occurred_after { nil }
    wayback_timestamp { "20220112122447" }
    source_csv_url { "https://assets.publishing.service.gov.uk/file1.csv" }
  end
end
