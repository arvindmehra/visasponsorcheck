require "csv"

class SponsorCsvParser
  def self.call(file_path, &block)
    new(file_path).parse(&block)
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def parse
    unless File.exist?(@file_path)
      raise "CSV file does not exist at #{@file_path}"
    end

    csv_options = {
      headers: true,
      header_converters: :symbol,
      encoding: "bom|utf-8",
      skip_blanks: true
    }

    rows = []
    CSV.foreach(@file_path, **csv_options) do |row|
      normalized = normalize_row(row)
      next if normalized[:organisation_name].blank?

      if block_given?
        yield normalized
      else
        rows << normalized
      end
    end
    rows unless block_given?
  end

  private

  def normalize_row(row)
    hash = row.to_h

    organisation_name = find_value(hash, [/organisation.*name/i, /company.*name/i, /name/i])
    town = find_value(hash, [/town.*city/i, /town/i, /city/i])
    county = find_value(hash, [/county/i])
    type_and_rating = find_value(hash, [/type.*rating/i, /rating/i])
    route = find_value(hash, [/route/i])

    {
      organisation_name: organisation_name&.to_s&.strip,
      town: town&.to_s&.strip,
      county: county&.to_s&.strip,
      type_and_rating: type_and_rating&.to_s&.strip,
      route: route&.to_s&.strip
    }
  end

  def find_value(hash, regexes)
    regexes.each do |regex|
      key = hash.keys.find { |k| k.to_s.gsub("_", " ").match?(regex) }
      return hash[key] if key
    end
    nil
  end
end
