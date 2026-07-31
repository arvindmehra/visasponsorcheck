require "set"

# Compares two parsed register snapshots (arrays of row hashes shaped like
# SponsorCsvParser's output) and reports which (company name, route) pairs
# appeared or disappeared between them. Pure/stateless — no DB access — so
# it's trivially testable independent of everything Wayback-related.
class SponsorHistoryDiffer
  Result = Struct.new(:added, :removed, keyword_init: true)

  def self.call(previous_rows:, current_rows:)
    previous_keys = to_keys(previous_rows)
    current_keys = to_keys(current_rows)

    Result.new(
      added: (current_keys - previous_keys).to_a,
      removed: (previous_keys - current_keys).to_a
    )
  end

  def self.to_keys(rows)
    rows.filter_map { |row|
      name = row[:organisation_name].to_s.strip.downcase
      route = row[:route].to_s.strip
      next if name.blank? || route.blank?

      [ name, route ]
    }.to_set
  end
end
