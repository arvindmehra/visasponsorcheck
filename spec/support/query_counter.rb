# Counts real SQL queries issued during a block, for asserting the absence
# of N+1s (excludes SCHEMA and CACHE notifications, which aren't real
# round-trips to Postgres).
module QueryCounter
  def count_queries(&block)
    count = 0
    counter = ->(_name, _started, _finished, _unique_id, payload) {
      count += 1 unless payload[:name].in?(%w[SCHEMA CACHE])
    }
    ActiveSupport::Notifications.subscribed(counter, "sql.active_record", &block)
    count
  end
end

RSpec.configure do |config|
  config.include QueryCounter, type: :request
end
