if ENV["HTTP_USERNAME"].present? && ENV["HTTP_PASSWORD"].present?
  PgHero::Engine.middleware.use Rack::Auth::Basic do |username, password|
    ActiveSupport::SecurityUtils.secure_compare(username, ENV["HTTP_USERNAME"]) &
      ActiveSupport::SecurityUtils.secure_compare(password, ENV["HTTP_PASSWORD"])
  end
end
