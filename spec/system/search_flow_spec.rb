require "rails_helper"

RSpec.describe "Search Flow", type: :system, js: true do
  let!(:company) { create(:company, name: "Google UK Ltd", town: "London") }
  let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker", rating: "A", status: "active") }

  before do
    # Warm up search indexes
    Company.connection.execute("SET pg_trgm.similarity_threshold = 0.15")
  end

  it "allows a user to search for a company name and view details" do
    visit root_path

    expect(page).to have_content("UK Visa Sponsor Registry")

    # Perform search
    fill_in "search-input-field", with: "Google"

    # Press Enter to perform search
    find("#search-input-field").native.send_keys(:enter)

    # Verify search results page is loaded
    expect(page).to have_content(/Search Results/i)
    expect(page).to have_link("Google UK Ltd")

    # Navigate to company show page
    click_link "Google UK Ltd"


    # Verify details on show page
    expect(page).to have_current_path(company_path(company))
    expect(page).to have_content("Google UK Ltd")
    expect(page).to have_content("Active Sponsor")
    expect(page).to have_content("Skilled Worker")
  end
end
