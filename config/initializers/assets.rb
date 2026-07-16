# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = "1.0"

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

require "propshaft/compiler"

class SimpleCssMinifier < Propshaft::Compiler
  def compile(logical_path, input)
    return input unless Rails.env.production?

    # Basic CSS Minification
    content = input.dup
    content.gsub!(/\/\*.*?\*\//m, "") # remove comments
    content.gsub!(/\s+/, " ")        # compress spaces
    content.gsub!(/\s*([\{\}:;,])\s*/, '\1') # remove space around delimiters
    content.strip
  end
end

class SimpleJsMinifier < Propshaft::Compiler
  def compile(logical_path, input)
    return input unless Rails.env.production?

    # Basic JS Minification (safe whitespace/comment removal)
    lines = input.split("\n").map do |line|
      if line.include?("//")
        parts = line.split("//", 2)
        if parts[0].count("'").odd? || parts[0].count('"').odd? || parts[0].count('`').odd?
          line
        else
          parts[0]
        end
      else
        line
      end
    end
    
    content = lines.join("\n")
    content.gsub!(/\/\*.*?\*\//m, "") # remove block comments
    
    # Strip leading/trailing whitespaces and empty lines
    content.split("\n").map(&:strip).reject(&:empty?).join("\n")
  end
end

Rails.application.config.assets.compilers << [SimpleCssMinifier, mime_types: ["text/css"]]
Rails.application.config.assets.compilers << [SimpleJsMinifier, mime_types: ["application/javascript"]]
