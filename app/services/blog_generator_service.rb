require "httparty"
require "nokogiri"

class BlogGeneratorService
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models"

  BANNED_PHRASES = [
    "delve into",
    "tapestry",
    "beacon",
    "testament to",
    "in today's fast-paced world",
    "digital landscape",
    "game-changer",
    "it is important to note",
    "it is crucial to remember",
    "in conclusion",
    "to sum up",
    "furthermore",
    "moreover"
  ].freeze

  RSS_FEEDS = [
    "https://www.gov.uk/government/organisations/uk-visas-and-immigration.atom",
    "https://www.gov.uk/government/organisations/migration-advisory-committee.atom",
    "https://freemovement.org.uk/feed/",
    "https://www.reddit.com/r/ukvisa/hot.rss"
  ].freeze

  def self.call(topic: nil, source_url: nil, raw_content: nil)
    new(topic: topic, source_url: source_url, raw_content: raw_content).perform
  end

  def initialize(topic: nil, source_url: nil, raw_content: nil)
    @topic = topic
    @source_url = source_url
    @raw_content = raw_content
    @api_key = Rails.application.credentials.dig(:gemini, :api_key)
  end

  def perform
    raise "GEMINI_API_KEY is not set" if @api_key.blank?

    source_data = fetch_or_prepare_source
    return { success: false, error: "No new source data found to ingest" } if source_data.nil?

    blog_json = generate_content_with_gemini(source_data)
    return { success: false, error: "Gemini generation failed" } if blog_json.nil?

    quality_report = evaluate_quality(blog_json)
    if quality_report[:score] < 80
      return {
        success: false,
        error: "Quality Gate Failed (Score: #{quality_report[:score]}/100)",
        issues: quality_report[:issues]
      }
    end

    image_url = generate_imagen_banner(blog_json["image_prompt"])

    blog = Blog.create!(
      title: blog_json["title"],
      slug: blog_json["slug"],
      category: blog_json["category"],
      meta_description: blog_json["meta_description"],
      key_takeaways: blog_json["key_takeaways"] || [],
      content_html: blog_json["content_html"],
      featured_image_url: image_url,
      quality_score: quality_report[:score],
      status: "pending_review",
      source_url: @source_url
    )

    BlogIngestionLog.mark_processed!(@source_url, title: blog.title) if @source_url.present?

    { success: true, blog: blog, quality_report: quality_report }
  rescue => e
    Rails.logger.error("[BlogGeneratorService Error]: #{e.message}\n#{e.backtrace.join("\n")}")
    { success: false, error: e.message }
  end

  private

  def fetch_or_prepare_source
    if @topic.present?
      return { topic: @topic, body: @raw_content || @topic }
    end

    # Fetch feeds and find first unprocessed story
    RSS_FEEDS.each do |feed_url|
      response = HTTParty.get(feed_url, headers: { "User-Agent" => "VisaSponsorCheck/1.0" }, timeout: 10)
      next unless response.success?

      doc = Nokogiri::XML(response.body)
      # Check Atom entry or RSS item
      items = doc.xpath("//xmlns:entry")
      items = doc.xpath("//item") if items.empty?

      items.each do |item|
        link = item.at_xpath("xmlns:link/@href")&.text || item.at_xpath("link")&.text
        title = item.at_xpath("xmlns:title")&.text || item.at_xpath("title")&.text
        summary = item.at_xpath("xmlns:summary")&.text || item.at_xpath("description")&.text

        next if link.blank? || BlogIngestionLog.already_processed?(link)

        @source_url = link
        @topic = title
        return { topic: title, body: summary, url: link }
      end
    end

    nil
  end

  def generate_content_with_gemini(source_data)
    url = "#{GEMINI_API_URL}/gemini-1.5-pro:generateContent?key=#{@api_key}"

    system_instruction = <<~SYS
      You are a senior UK immigration solicitor and legal content editor.
      STRICT ANTI-AI-SLOP RULES:
      1. Never use clichés like 'delve into', 'tapestry', 'beacon', 'game-changer', 'in today's fast-paced world', or 'in conclusion'.
      2. Start directly with the headline rule or policy update in sentence 1.
      3. Include specific figures, effective 2026 dates, SOC codes, or UKVI guidance paragraph IDs.
      4. Target audience: UK HR Managers, Business Directors, and Skilled Worker applicants.
    SYS

    json_schema = {
      type: "OBJECT",
      properties: {
        title: { type: "STRING" },
        slug: { type: "STRING" },
        category: { type: "STRING", enum: Blog::CATEGORIES },
        meta_description: { type: "STRING" },
        key_takeaways: { type: "ARRAY", items: { type: "STRING" } },
        content_html: { type: "STRING" },
        image_prompt: { type: "STRING" }
      },
      required: [ "title", "slug", "category", "meta_description", "key_takeaways", "content_html", "image_prompt" ]
    }

    prompt = <<~PROMPT
      Topic: #{source_data[:topic]}
      Source Detail: #{source_data[:body]}

      Generate an authoritative, highly practical UK immigration blog post for 2026.
      Output pure JSON matching the specified schema.
    PROMPT

    body = {
      systemInstruction: { parts: [ { text: system_instruction } ] },
      contents: [ { parts: [ { text: prompt } ] } ],
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: json_schema,
        temperature: 0.3
      }
    }

    response = HTTParty.post(
      url,
      headers: { "Content-Type" => "application/json" },
      body: body.to_json,
      timeout: 30
    )

    return nil unless response.success?

    text_output = response.parsed_response.dig("candidates", 0, "content", "parts", 0, "text")
    return nil if text_output.blank?

    JSON.parse(text_output)
  end

  def evaluate_quality(blog_json)
    score = 100
    issues = []
    content = blog_json["content_html"].to_s.downcase

    # Check 1: Banned Phrases
    BANNED_PHRASES.each do |phrase|
      if content.include?(phrase)
        score -= 15
        issues << "Banned phrase detected: '#{phrase}'"
      end
    end

    # Check 2: Data Density (Must contain numbers/dates/fees)
    number_matches = content.scan(/\b\d+\b/)
    if number_matches.size < 5
      score -= 15
      issues << "Low data density: fewer than 5 numerical figures/dates found."
    end

    # Check 3: HTML Structure
    unless content.include?("<h2") && content.include?("<ul")
      score -= 20
      issues << "Missing HTML elements: post must contain <h2> and <ul> lists."
    end

    # Check 4: Word count
    word_count = blog_json["content_html"].to_s.gsub(/<[^>]*>/, " ").split.size
    if word_count < 400
      score -= 20
      issues << "Article too short (#{word_count} words). Minimum target is 400+ words."
    end

    { score: [ score, 0 ].max, issues: issues }
  end

  def generate_imagen_banner(image_prompt)
    url = "#{GEMINI_API_URL}/imagen-3.0-generate-002:generateImages?key=#{@api_key}"

    body = {
      prompt: "Modern professional 3D vector illustration, clean corporate UK blue theme: #{image_prompt}",
      config: {
        numberOfImages: 1,
        outputMimeType: "image/jpeg",
        aspectRatio: "16:9"
      }
    }

    response = HTTParty.post(
      url,
      headers: { "Content-Type" => "application/json" },
      body: body.to_json,
      timeout: 25
    )

    if response.success?
      base64_data = response.parsed_response.dig("generatedImages", 0, "image", "imageBytes")
      if base64_data.present?
        return "data:image/jpeg;base64,#{base64_data}"
      end
    end

    # Fallback image placeholder
    "/logo-wpc.png"
  rescue => e
    Rails.logger.warn("[Imagen Generation Warning]: #{e.message}")
    "/logo-wpc.png"
  end
end
