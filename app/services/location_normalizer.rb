module LocationNormalizer
  MAPPING = {
    "abbeywood" => "Abbey Wood",
    "abbey wood" => "Abbey Wood",
    "abindgon" => "Abingdon",
    "abotts langely" => "Abbots Langley",
    "abbots langley" => "Abbots Langley",
    "abergavvany" => "Abergavenny",
    "aberystywth" => "Aberystwyth",
    "stratford-upon-avon" => "Stratford-upon-Avon",
    "newcastle-upon-tyne" => "Newcastle upon Tyne",
    "kingston-upon-hull" => "Kingston upon Hull"
  }.freeze

  # Returns the normalized/corrected display name for a city/town
  def self.normalize(town_name)
    return nil if town_name.blank?

    cleaned = town_name.to_s.strip.gsub(/\s+/, " ")
    MAPPING[cleaned.downcase] || MAPPING[cleaned.downcase.gsub("-", " ")] || cleaned
  end

  # Returns the canonical hyphenated slug for a city/town
  def self.canonical_slug(town_name)
    return nil if town_name.blank?

    normalized = normalize(town_name)
    normalized.downcase.gsub(/[^a-z0-9 -]/, "").gsub(/\s+/, "-")
  end

  # Recovers the capitalized display name from a slug
  def self.canonical_name(slug)
    return nil if slug.blank?

    # Try mapping lookup
    normalized_slug = slug.to_s.downcase.strip.gsub(/\s+/, "-")
    match = MAPPING.values.find { |name| canonical_slug(name) == normalized_slug }
    return match if match

    # Fallback to capitalize parts
    normalized_slug.split("-").map(&:capitalize).join(" ")
  end
end
