class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @companies = if @query.present?
                   Company.fuzzy_search(@query).limit(20).includes(:sponsor_licences)
    else
                   Company.none
    end

    log_search if @query.present? && !typeahead_request?

    # Support rendering with or without layout for Turbo Frame requests
    if turbo_frame_request?
      if request.headers["Turbo-Frame"] == "typeahead_results"
        render partial: "search/typeahead", locals: { companies: @companies, query: @query }
      else
        render layout: false
      end
    else
      render
    end
  end

  private

  # Typeahead fires on every keystroke (debounced) against this same action —
  # only log deliberate, completed searches (full page loads / Enter-key
  # submits), not every partial query the user types along the way.
  def typeahead_request?
    request.headers["Turbo-Frame"] == "typeahead_results"
  end

  def log_search
    SearchLog.create!(query: @query.downcase, results_count: @companies.size)
  rescue => e
    Rails.logger.error("Failed to log search: #{e.message}")
  end
end
