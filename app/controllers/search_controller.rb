class SearchController < ApplicationController
  def index
    @query = params[:q].to_s.strip
    @companies = if @query.present?
                   Company.fuzzy_search(@query).limit(20).includes(:sponsor_licences)
                 else
                   Company.none
                 end

    # Support rendering with or without layout for Turbo Frame requests
    if turbo_frame_request?
      render layout: false
    else
      render
    end
  end
end
