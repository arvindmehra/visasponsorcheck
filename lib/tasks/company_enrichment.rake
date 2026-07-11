# Usage:
#   bin/rails companies:backfill_profiles                       # companies with a company_number but no profile
#   bin/rails companies:enrich_missing                           # companies with no company_number at all
#   SLEEP_INTERVAL=1.0 BATCH_SIZE=50 bin/rails companies:backfill_profiles   # override rate-limit pacing / batch size
#   RATE_LIMIT_BACKOFF=300 RATE_LIMIT_MAX_RETRIES=5 bin/rails companies:backfill_profiles  # override 429 backoff/retry
#
# In Docker: docker exec visasponsoruk-web bin/rails companies:backfill_profiles

# Shared pacing/backoff config for both tasks below, read from ENV so it can be
# tuned per-run without editing this file.
def enrichment_task_options
  [
    ENV.fetch("SLEEP_INTERVAL", "0.5").to_f,
    ENV.fetch("BATCH_SIZE", "100").to_i,
    ENV.fetch("RATE_LIMIT_BACKOFF", "61").to_f,
    ENV.fetch("RATE_LIMIT_MAX_RETRIES", "5").to_i
  ]
end

namespace :companies do
  desc "Backfill company profiles for companies that already have a company_number but no profile data"
  task backfill_profiles: :environment do
    sleep_interval, batch_size, rate_limit_backoff, rate_limit_max_retries = enrichment_task_options

    companies = Company.where.not(company_number: [ nil, "" ])
                       .left_joins(:company_profile)
                       .where(company_profiles: { id: nil })

    total = companies.count
    puts "Found #{total} companies with company_number but no profile data."
    puts "Sleep interval: #{sleep_interval}s | Batch size: #{batch_size} | Rate limit backoff: #{rate_limit_backoff}s (max #{rate_limit_max_retries} retries)"
    puts "-" * 60

    success = 0
    failed = 0

    companies.find_each(batch_size: batch_size).with_index do |company, index|
      print "[#{index + 1}/#{total}] #{company.name} (#{company.company_number})... "
      attempts = 0

      begin
        attempts += 1
        CompanyProfileEnricher.enrich!(company)
        profile = company.reload.company_profile

        if profile&.company_status.present?
          puts "✓ #{profile.company_status} | #{profile.company_type_label} | SIC: #{profile.sic_code}"
          success += 1
        else
          puts "✗ No profile data returned"
          failed += 1
        end
      rescue CompaniesHouseClient::RateLimitError
        if attempts <= rate_limit_max_retries
          puts "⏳ rate limited, waiting #{rate_limit_backoff}s before retrying (attempt #{attempts}/#{rate_limit_max_retries})..."
          sleep(rate_limit_backoff)
          retry
        else
          puts "✗ Still rate limited after #{attempts} attempts, skipping for now"
          failed += 1
        end
      rescue => e
        puts "✗ Error: #{e.message}"
        failed += 1
      end

      sleep(sleep_interval)
    end

    puts "-" * 60
    puts "Done! Success: #{success} | Failed: #{failed} | Total: #{total}"
  end

  desc "Enrich companies that have no company data at all (no company_number)"
  task enrich_missing: :environment do
    sleep_interval, batch_size, rate_limit_backoff, rate_limit_max_retries = enrichment_task_options

    companies = Company.where(enriched_at: nil)
                       .where(company_number: [ nil, "" ])

    total = companies.count
    puts "Found #{total} companies with no enrichment data."
    puts "Sleep interval: #{sleep_interval}s | Batch size: #{batch_size} | Rate limit backoff: #{rate_limit_backoff}s (max #{rate_limit_max_retries} retries)"
    puts "-" * 60

    success = 0
    failed = 0

    companies.find_each(batch_size: batch_size).with_index do |company, index|
      print "[#{index + 1}/#{total}] #{company.name}... "
      attempts = 0

      begin
        attempts += 1

        # Step 1: Search by name to get company_number
        CompanyEnricher.enrich!(company)
        company.reload

        if company.company_number.present?
          # Step 2: Fetch full profile (synchronously, not via job)
          CompanyProfileEnricher.enrich!(company)
          profile = company.reload.company_profile

          if profile&.company_status.present?
            puts "✓ #{company.company_number} | #{profile.company_status} | SIC: #{profile.sic_code}"
            success += 1
          else
            puts "~ Found #{company.company_number} but no profile data"
            success += 1
          end
        else
          puts "✗ No company_number found"
          failed += 1
        end
      rescue CompaniesHouseClient::RateLimitError
        if attempts <= rate_limit_max_retries
          puts "⏳ rate limited, waiting #{rate_limit_backoff}s before retrying (attempt #{attempts}/#{rate_limit_max_retries})..."
          sleep(rate_limit_backoff)
          retry
        else
          puts "✗ Still rate limited after #{attempts} attempts, skipping for now"
          failed += 1
        end
      rescue => e
        puts "✗ Error: #{e.message}"
        failed += 1
      end

      sleep(sleep_interval)
    end

    puts "-" * 60
    puts "Done! Success: #{success} | Failed: #{failed} | Total: #{total}"
  end
end
