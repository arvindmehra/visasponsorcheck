class SponsorImporter
  def self.call(source = nil)
    new(source).import
  end

  def initialize(source = nil)
    @source = source
  end

  def import
    import_log = create_import_log
    import_log.start!

    begin
      download_result = download_csv(import_log)

      counts = { new: 0, updated: 0, removed: 0, total: 0 }
      errors = []

      process_csv_rows(download_result[:path], import_log, counts, errors)
      counts[:removed] = mark_unseen_licences_as_removed(import_log, errors)

      error_message = write_error_csv_if_needed(import_log, errors)
      finalize_import_log(import_log, counts, error_message)

      cleanup_temp_file(download_result[:path])

      import_log
    rescue => e
      import_log.fail!(e.message)
      raise e
    end
  end

  private

  def create_import_log
    SponsorImportLog.create!(
      source_url: @source || SponsorCsvDownloader::GOV_UK_URL,
      status: "pending"
    )
  end

  def download_csv(import_log)
    download_result = SponsorCsvDownloader.call(@source)
    import_log.update!(
      source_url: download_result[:url],
      csv_filename: download_result[:filename]
    )
    download_result
  end

  def process_csv_rows(path, import_log, counts, errors)
    SponsorCsvParser.call(path) do |row|
      counts[:total] += 1

      begin
        result = process_row(row, import_log)
        counts[result] += 1 if result
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
  end

  def process_row(row, import_log)
    ActiveRecord::Base.transaction do
      company = upsert_company(row)
      upsert_licence(row, company, import_log)
    end
  end

  def upsert_company(row)
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
      company.town = row[:town] if row[:town].present?
      company.county = row[:county] if row[:county].present?
      company.save! if company.changed?
    end
    company
  end

  def upsert_licence(row, company, import_log)
    parsed_type_rating = SponsorLicence.parse_type_and_rating(row[:type_and_rating])
    unless parsed_type_rating
      raise ArgumentError, "Unparseable Type & Rating: #{row[:type_and_rating]}"
    end

    licence_type = parsed_type_rating[:licence_type]
    rating = parsed_type_rating[:rating]
    route = row[:route]

    licence = SponsorLicence.find_or_initialize_by(company_id: company.id, route: route)

    if licence.new_record?
      licence.assign_attributes(
        organisation_name: row[:organisation_name].strip,
        licence_type: licence_type,
        rating: rating,
        status: "active",
        first_seen_at: import_log.started_at,
        last_seen_at: import_log.started_at
      )
      licence.save!

      SponsorChangeEvent.create!(
        company: company,
        sponsor_import_log: import_log,
        event_type: "added",
        occurred_at: import_log.started_at
      )
      :new
    else
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
        :updated
      else
        licence.update_columns(last_seen_at: import_log.started_at)
        nil
      end
    end
  end

  def mark_unseen_licences_as_removed(import_log, errors)
    removed_count = 0
    # FIX N+1 Query: pre-load company
    unseen_licences = SponsorLicence.active.includes(:company).where("last_seen_at < ?", import_log.started_at)
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
    removed_count
  end

  def write_error_csv_if_needed(import_log, errors)
    return nil if errors.empty?

    begin
      require "fileutils"
      error_dir = Rails.root.join("tmp", "import_errors")
      FileUtils.mkdir_p(error_dir)
      error_filename = "errors_#{import_log.id}_#{Time.current.strftime('%Y%m%d%H%M%S')}.csv"
      error_path = error_dir.join(error_filename)

      require "csv"
      CSV.open(error_path, "wb") do |csv|
        csv << [ "Company Name", "Route", "Town", "County", "Error Message" ]
        errors.each do |err|
          csv << [ err[:company_name], err[:route], err[:town], err[:county], err[:error_message] ]
        end
      end
      "Import completed with #{errors.size} row failures. Error log saved at: #{error_path}"
    rescue => e
      "Import completed with #{errors.size} row failures. Failed to save CSV error log: #{e.message}"
    end
  end

  def finalize_import_log(import_log, counts, error_message)
    import_log.finish!(
      total_rows: counts[:total],
      new_licences: counts[:new],
      updated_licences: counts[:updated],
      removed_licences: counts[:removed]
    )

    import_log.update!(error_message: error_message) if error_message.present?
  end

  def cleanup_temp_file(path)
    if path && File.basename(path).start_with?("sponsor_register")
      File.delete(path) if File.exist?(path)
    end
  end
end
