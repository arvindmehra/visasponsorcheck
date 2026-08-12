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

  # Returns all matching slug/town database variations for a city
  def self.all_slug_variants(town_name)
    return [] if town_name.blank?

    slug = town_name.to_s.downcase.strip
    unhyphenated = slug.gsub("-", "")
    spaced = slug.gsub("-", " ")
    canonical = canonical_slug(spaced)

    normalized_name = normalize(spaced) || normalize(slug)
    mapping_keys = MAPPING.select { |_k, v| v.downcase == normalized_name.downcase }.keys
    mapping_slugs = mapping_keys.map { |k| k.gsub(/[^a-z0-9 -]/, "").gsub(/\s+/, "-") }

    ([ slug, unhyphenated, spaced, canonical ] + mapping_keys + mapping_slugs)
      .compact_blank
      .map(&:downcase)
      .uniq
  end
end
