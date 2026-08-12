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
    @api_attempts = []
    @feed_attempts = []
  end

  def perform
    if @api_key.blank?
      return { 
        success: false, 
        stage: :api_key_check,
        error: "Gemini API key missing in Rails credentials under gemini.api_key",
        troubleshooting: "Run 'bin/rails credentials:edit' and set gemini.api_key: 'YOUR_GEMINI_KEY'.",
        details: {
          credentials_file_exists: File.exist?(Rails.root.join("config/credentials.yml.enc")),
          master_key_exists: File.exist?(Rails.root.join("config/master.key")) || ENV["RAILS_MASTER_KEY"].present?
        }
      }
    end

    source_data = fetch_or_prepare_source
    if source_data.nil?
      return { 
        success: false, 
        stage: :source_ingestion,
        error: "No new source data found across RSS feeds",
        troubleshooting: "All feed articles may have already been processed in 'blog_ingestion_logs'. Try passing a manual topic e.g. BlogGeneratorService.call(topic: 'Your Custom Topic').",
        details: { feed_attempts: @feed_attempts }
      }
    end

    blog_json = generate_content_with_gemini(source_data)
    if blog_json.nil?
      return { 
        success: false, 
        stage: :ai_generation,
        error: "Gemini AI generation failed across all attempted models",
        troubleshooting: "Check if your Gemini API key has access to 'gemini-1.5-flash' / 'gemini-1.5-pro' on Google AI Studio (aistudio.google.com) and has quota remaining.",
        details: { 
          source_topic: source_data[:topic],
          api_attempts: @api_attempts 
        }
      }
    end

    quality_report = evaluate_quality(blog_json)
    if quality_report[:score] < 80
      return {
        success: false,
        stage: :quality_gate,
        error: "Quality Gate Failed (Score: #{quality_report[:score]}/100, Minimum required: 80)",
        troubleshooting: "The generated article was flagged for low depth, missing structural elements, or containing banned AI clichés.",
        issues: quality_report[:issues],
        details: { quality_score: quality_report[:score] }
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
    { 
      success: false, 
      stage: :exception,
      error: "Unexpected runtime exception: #{e.message}",
      troubleshooting: "Inspect application logs or stacktrace for details.",
      details: { exception_class: e.class.name, backtrace: e.backtrace.first(5) }
    }
  end

  private

  def fetch_or_prepare_source
    if @topic.present?
      return { topic: @topic, body: @raw_content || @topic }
    end

    RSS_FEEDS.each do |feed_url|
      begin
        response = HTTParty.get(feed_url, headers: { "User-Agent" => "VisaSponsorCheck/1.0" }, timeout: 10)
        unless response.success?
          @feed_attempts << { feed: feed_url, status: response.code, error: response.body }
          next
        end

        doc = Nokogiri::XML(response.body)
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
        @feed_attempts << { feed: feed_url, status: 200, note: "All stories already processed" }
      rescue => e
        @feed_attempts << { feed: feed_url, status: "error", error: e.message }
      end
    end

    nil
  end

  def generate_content_with_gemini(source_data)
    models_to_try = [ "gemini-1.5-flash", "gemini-1.5-pro", "gemini-2.0-flash" ]

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

    models_to_try.each do |model_name|
      url = "#{GEMINI_API_URL}/#{model_name}:generateContent?key=#{@api_key}"

      begin
        response = HTTParty.post(
          url,
          headers: { "Content-Type" => "application/json" },
          body: body.to_json,
          timeout: 30
        )

        if response.success?
          text_output = response.parsed_response.dig("candidates", 0, "content", "parts", 0, "text")
          if text_output.present?
            @api_attempts << { model: model_name, status: "success", code: response.code }
            return JSON.parse(text_output)
          else
            @api_attempts << { model: model_name, status: "empty_response", code: response.code }
          end
        else
          error_data = response.parsed_response.is_a?(Hash) ? response.parsed_response.dig("error") : nil
          api_message = error_data ? error_data["message"] : response.body
          api_status = error_data ? error_data["status"] : "HTTP_#{response.code}"

          @api_attempts << { 
            model: model_name, 
            status: "failed", 
            code: response.code, 
            api_status: api_status,
            message: api_message 
          }
          Rails.logger.warn("[BlogGeneratorService] #{model_name} API Error [#{response.code}]: #{api_message}")
        end
      rescue => e
        @api_attempts << { model: model_name, status: "exception", error: e.message }
      end
    end

    nil
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

    "/logo-wpc.png"
  rescue => e
    Rails.logger.warn("[Imagen Generation Warning]: #{e.message}")
    "/logo-wpc.png"
  end
end
