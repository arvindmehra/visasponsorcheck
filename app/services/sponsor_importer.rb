class SponsorImporter
  def self.call(source = nil)
    new(source).import
  end

  def initialize(source = nil)
    @source = source
  end

  def import
    import_log = SponsorImportLog.create!(
      source_url: @source || SponsorCsvDownloader::GOV_UK_URL,
      status: "pending"
    )

    import_log.start!

    begin
      # 1. Download CSV
      download_result = SponsorCsvDownloader.call(@source)
      import_log.update!(
        source_url: download_result[:url],
        csv_filename: download_result[:filename]
      )

      # 2. Parse and upsert rows as they are read with row-level recovery
      new_count = 0
      updated_count = 0
      removed_count = 0
      total_rows = 0
      errors = []

      SponsorCsvParser.call(download_result[:path]) do |row|
        total_rows += 1

        begin
          # Use row-level transactions so single-row failures do not abort other records
          ActiveRecord::Base.transaction do
            # Find or create company
            normalised_name = row[:organisation_name].to_s.strip.gsub(/\s+/, " ")
            raise ArgumentError, "Organisation name is blank" if normalised_name.blank?

            name_normalised = normalised_name.downcase

            company = Company.find_or_initialize_by(name_normalised: name_normalised)
            if company.new_record?
              company.name = row[:organisation_name].strip
              company.name_normalised = normalised_name
              company.town = row[:town]
              company.county = row[:county]
              company.save!
            else
              # Update location if changed (dirty tracking handles this internally)
              company.town = row[:town] if row[:town].present?
              company.county = row[:county] if row[:county].present?
              company.save! if company.changed?
            end

            # Parse type and rating
            parsed_type_rating = SponsorLicence.parse_type_and_rating(row[:type_and_rating])
            unless parsed_type_rating
              raise ArgumentError, "Unparseable Type & Rating: #{row[:type_and_rating]}"
            end

            licence_type = parsed_type_rating[:licence_type]
            rating = parsed_type_rating[:rating]
            route = row[:route]

            # Find or initialize licence
            licence = SponsorLicence.find_or_initialize_by(company_id: company.id, route: route)

            if licence.new_record?
              # New licence
              licence.assign_attributes(
                organisation_name: row[:organisation_name].strip,
                licence_type: licence_type,
                rating: rating,
                status: "active",
                first_seen_at: import_log.started_at,
                last_seen_at: import_log.started_at
              )
              licence.save!
              new_count += 1

              SponsorChangeEvent.create!(
                company: company,
                sponsor_import_log: import_log,
                event_type: "added",
                occurred_at: import_log.started_at
              )
            else
              # Existing licence: assign attributes and check for changes
              licence.assign_attributes(
                organisation_name: row[:organisation_name].strip,
                licence_type: licence_type,
                rating: rating,
                status: "active"
              )

              if licence.changed?
                was_removed = licence.status_was == "removed"
                rating_changed = licence.rating_changed?
                licence_type_changed = licence.licence_type_changed?

                old_status = licence.status_was
                old_rating = licence.rating_was
                old_licence_type = licence.licence_type_was

                licence.last_seen_at = import_log.started_at
                licence.save!
                updated_count += 1

                if was_removed
                  SponsorChangeEvent.create!(
                    company: company,
                    sponsor_import_log: import_log,
                    event_type: "status_changed",
                    old_value: old_status,
                    new_value: "active",
                    occurred_at: import_log.started_at
                  )
                end

                if rating_changed
                  SponsorChangeEvent.create!(
                    company: company,
                    sponsor_import_log: import_log,
                    event_type: "rating_changed",
                    old_value: old_rating,
                    new_value: rating,
                    occurred_at: import_log.started_at
                  )
                end

                if licence_type_changed
                  SponsorChangeEvent.create!(
                    company: company,
                    sponsor_import_log: import_log,
                    event_type: "licence_type_changed",
                    old_value: old_licence_type,
                    new_value: licence_type,
                    occurred_at: import_log.started_at
                  )
                end
              else
                # No structural changes, just touch last_seen_at
                licence.update_columns(last_seen_at: import_log.started_at)
              end
            end
          end
        rescue => e
          errors << {
            company_name: row[:organisation_name],
            route: row[:route],
            town: row[:town],
            county: row[:county],
            error_message: e.message
          }
        end
      end

      # 3. Mark unseen active licences as removed
      unseen_licences = SponsorLicence.active.where("last_seen_at < ?", import_log.started_at)
      unseen_licences.find_each do |unseen|
        begin
          ActiveRecord::Base.transaction do
            unseen.update!(status: "removed")
            removed_count += 1

            SponsorChangeEvent.create!(
              company: unseen.company,
              sponsor_import_log: import_log,
              event_type: "removed",
              occurred_at: import_log.started_at
            )
          end
        rescue => e
          errors << {
            company_name: unseen.organisation_name,
            route: unseen.route,
            town: unseen.company&.town,
            county: unseen.company&.county,
            error_message: "Failed to mark as removed: #{e.message}"
          }
        end
      end

      # 4. Wrap up import log & write error CSV if any
      error_message = nil
      if errors.any?
        begin
          require "fileutils"
          error_dir = Rails.root.join("tmp", "import_errors")
          FileUtils.mkdir_p(error_dir)
          error_filename = "errors_#{import_log.id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
          error_path = error_dir.join(error_filename)

          require "csv"
          CSV.open(error_path, "wb") do |csv|
            csv << ["Company Name", "Route", "Town", "County", "Error Message"]
            errors.each do |err|
              csv << [err[:company_name], err[:route], err[:town], err[:county], err[:error_message]]
            end
          end
          error_message = "Import completed with #{errors.size} row failures. Error log saved at: #{error_path}"
        rescue => e
          error_message = "Import completed with #{errors.size} row failures. Failed to save CSV error log: #{e.message}"
        end
      end

      import_log.finish!(
        total_rows: total_rows,
        new_licences: new_count,
        updated_licences: updated_count,
        removed_licences: removed_count
      )

      import_log.update!(error_message: error_message) if error_message.present?

      # Clean up temp file if downloaded (avoid deleting local files)
      if download_result[:path] && File.basename(download_result[:path]).start_with?("sponsor_register")
        File.delete(download_result[:path]) if File.exist?(download_result[:path])
      end

      import_log
    rescue => e
      import_log.fail!(e.message)
      raise e
    end
  end

  private

  def local_file?(source)
    source.present? && File.exist?(source)
  end
end
