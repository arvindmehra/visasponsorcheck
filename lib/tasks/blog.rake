namespace :blog do
  desc "Trigger automatic blog generation from multi-source RSS feeds"
  task generate: :environment do
    puts "Starting blog generation..."
    result = BlogGeneratorService.call

    if result[:success]
      puts "✅ Success! Blog draft created:"
      puts "Title: #{result[:blog].title}"
      puts "Slug: #{result[:blog].slug}"
      puts "Quality Score: #{result[:quality_report][:score]}/100"
      puts "Status: #{result[:blog].status}"
    else
      puts "\n❌ Ingestion / Generation Failed!"
      puts "Stage: #{result[:stage]}"
      puts "Error: #{result[:error]}"
      
      if result[:troubleshooting].present?
        puts "\n💡 Troubleshooting Advice:"
        puts "   #{result[:troubleshooting]}"
      end

      if result[:issues].present?
        puts "\n⚠️ Quality Issues Found:"
        result[:issues].each { |issue| puts " - #{issue}" }
      end

      if result[:details].present?
        puts "\n🔍 Diagnostic Details:"
        puts JSON.pretty_generate(result[:details])
      end
    end
  end

  desc "List all pending draft blogs awaiting review"
  task pending: :environment do
    pending_blogs = Blog.pending_review
    if pending_blogs.none?
      puts "No pending blog drafts awaiting review."
    else
      puts "Found #{pending_blogs.count} pending blog draft(s):"
      pending_blogs.each do |blog|
        puts "[ID: #{blog.id}] #{blog.title} (Score: #{blog.quality_score}/100, Category: #{blog.category})"
        puts "  Slug: #{blog.slug}"
      end
    end
  end

  desc "Publish a draft blog by ID or Slug (e.g., bin/rails blog:publish[1] or bin/rails blog:publish[my-slug])"
  task :publish, [:id_or_slug] => :environment do |_t, args|
    id_or_slug = args[:id_or_slug]
    if id_or_slug.blank?
      puts "Please specify an ID or slug. Usage: bin/rails blog:publish[1] or bin/rails blog:publish_latest"
      next
    end

    blog = Blog.find_by(id: id_or_slug) || Blog.find_by(slug: id_or_slug)
    if blog.nil?
      puts "❌ Blog post not found for ID/slug: #{id_or_slug}"
    else
      blog.update!(status: "published", published_at: Time.current)
      puts "🎉 Published successfully!"
      puts "Title: #{blog.title}"
      puts "URL: /blog/#{blog.slug}"
    end
  end

  desc "Publish the latest pending draft blog"
  task publish_latest: :environment do
    blog = Blog.pending_review.first
    if blog.nil?
      puts "No pending drafts to publish."
    else
      blog.update!(status: "published", published_at: Time.current)
      puts "🎉 Published latest draft successfully!"
      puts "Title: #{blog.title}"
      puts "URL: /blog/#{blog.slug}"
    end
  end
end
