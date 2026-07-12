# Groups UK SIC 2007 codes into broad, human-recognisable industry sectors
# for the "Browse by Industry" feature. Grouping is at the SIC "division"
# level (the first 2 digits of a 5-digit SIC code), rolled up to match the
# official ONS/Companies House SIC 2007 sections — except section G (Wholesale
# and retail trade; repair of motor vehicles) is split into its three natural
# divisions (motor trade / wholesale / retail) since lumping them together
# hides meaningfully different industries from users browsing by sector.
class SicSector
  GROUPS = {
    "agriculture-forestry-fishing" => { name: "Agriculture, Forestry & Fishing", divisions: 1..3 },
    "mining-quarrying" => { name: "Mining & Quarrying", divisions: 5..9 },
    "manufacturing" => { name: "Manufacturing", divisions: 10..33 },
    "energy-supply" => { name: "Electricity, Gas & Air Conditioning Supply", divisions: 35..35 },
    "water-waste-management" => { name: "Water Supply, Sewerage & Waste Management", divisions: 36..39 },
    "construction" => { name: "Construction", divisions: 41..43 },
    "motor-vehicle-trade" => { name: "Motor Vehicle Trade & Repair", divisions: 45..45 },
    "wholesale-trade" => { name: "Wholesale Trade", divisions: 46..46 },
    "retail-trade" => { name: "Retail Trade", divisions: 47..47 },
    "transportation-storage" => { name: "Transportation & Storage", divisions: 49..53 },
    "accommodation-food-services" => { name: "Accommodation & Food Services", divisions: 55..56 },
    "information-communication" => { name: "Information & Communication (Software, Media, Telecoms)", divisions: 58..63 },
    "financial-insurance" => { name: "Financial & Insurance Activities", divisions: 64..66 },
    "real-estate" => { name: "Real Estate", divisions: 68..68 },
    "professional-scientific-technical" => { name: "Professional, Scientific & Technical Activities", divisions: 69..75 },
    "administrative-support-services" => { name: "Administrative & Support Services", divisions: 77..82 },
    "public-administration-defence" => { name: "Public Administration & Defence", divisions: 84..84 },
    "education" => { name: "Education", divisions: 85..85 },
    "health-social-work" => { name: "Human Health & Social Work Activities", divisions: 86..88 },
    "arts-entertainment-recreation" => { name: "Arts, Entertainment & Recreation", divisions: 90..93 },
    "other-services" => { name: "Other Service Activities", divisions: 94..96 },
    "household-employers" => { name: "Activities of Households as Employers", divisions: 97..98 },
    "extraterritorial-organisations" => { name: "Extraterritorial Organisations", divisions: 99..99 }
  }.freeze

  def self.keys
    GROUPS.keys
  end

  def self.name_for(key)
    GROUPS.dig(key, :name)
  end

  def self.division_range(key)
    GROUPS.dig(key, :divisions)
  end

  # Which sector a raw SIC code (e.g. "62090" or 62090) belongs to, or nil.
  def self.for_sic_code(code)
    division = code.to_i / 1000
    GROUPS.find { |_, group| group[:divisions].cover?(division) }&.first
  end

  # { sector_key => count_of_distinct_active_companies }, computed in a single
  # query and bucketed in Ruby, rather than one query per sector.
  def self.active_company_counts
    counts_by_division = Company
      .joins(:sponsor_licences, :company_profile)
      .where(sponsor_licences: { status: "active" })
      .where.not(company_profiles: { sic_code: nil })
      .distinct
      .group(Arel.sql("company_profiles.sic_code / 1000"))
      .count("companies.id")

    GROUPS.each_with_object({}) do |(key, group), totals|
      totals[key] = counts_by_division.sum { |division, count| group[:divisions].cover?(division) ? count : 0 }
    end
  end

  # [{ key:, name:, count: }, ...] sorted by company count descending.
  # Pass only_populated: true to drop sectors with zero companies (for compact
  # "top sectors" widgets); the full "Browse by Industry" index shows all of
  # them, including empty ones, since it's a fixed taxonomy.
  def self.ranked(limit: nil, only_populated: false)
    counts = active_company_counts
    sectors = GROUPS.keys.map { |key| { key: key, name: name_for(key), count: counts[key] } }
    sectors = sectors.select { |s| s[:count] > 0 } if only_populated
    sectors = sectors.sort_by { |s| -s[:count] }
    limit ? sectors.first(limit) : sectors
  end
end
