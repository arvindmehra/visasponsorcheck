class DataQualityAudit
  def self.run
    new.run
  end

  def run
    anomalies = []

    # 1. Check companies with town but missing town_normalised
    missing_slugs = Company.where.not(town: [nil, ""]).where(town_normalised: [nil, ""]).count
    if missing_slugs > 0
      anomalies << "Found #{missing_slugs} companies with town names but missing normalised town slugs."
    end

    # 2. Check spelling drift / non-canonical town names for active companies
    non_canonical_towns = Company.active_sponsors
                                 .where.not(town: [nil, ""])
                                 .pluck(:town)
                                 .uniq
                                 .select { |t| LocationNormalizer.normalize(t) != t }
    if non_canonical_towns.any?
      anomalies << "Found #{non_canonical_towns.size} active companies with non-canonical town names (e.g. #{non_canonical_towns.first(3).join(', ')})."
    end

    # 3. Check active count drop/spike from previous import log
    logs = SponsorImportLog.done.recent.limit(2).to_a
    if logs.size == 2
      current_total = logs[0].total_rows || 0
      previous_total = logs[1].total_rows || 0
      if previous_total > 0
        pct_change = ((current_total - previous_total).to_f / previous_total * 100).abs
        if pct_change > 15.0
          anomalies << "Sponsor count changed drastically by #{pct_change.round(1)}% (from #{previous_total} to #{current_total})."
        end
      end
    end

    # Log anomalies to Rails logger
    if anomalies.any?
      Rails.logger.warn("[DATA QUALITY AUDIT WARNINGS]\n" + anomalies.join("\n"))
    else
      Rails.logger.info("[DATA QUALITY AUDIT] Clean run. No anomalies detected.")
    end

    anomalies
  end
end
