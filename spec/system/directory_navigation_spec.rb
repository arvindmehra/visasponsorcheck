require "rails_helper"

RSpec.describe "Directory Navigation Flow", type: :system, js: true do
  let!(:company) { create(:company, name: "Amazon UK Services", town: "Manchester") }
  let!(:licence) { create(:sponsor_licence, company: company, route: "Skilled Worker", rating: "A", status: "active") }

  it "allows a user to browse directory pages and view company details" do
    visit root_path

    # Click on the Browse Sponsors link in the footer to avoid hidden responsive header link issues
    within("footer") do
      click_link "Browse Sponsors"
    end

    # Verify sponsors directory page loads
    expect(page).to have_content("UK Visa Sponsor Directory")

    expect(page).to have_content("Browse by City")

    # Click on Manchester city
    click_link "Manchester"

    # Verify city sponsors page loads
    expect(page).to have_content("Visa Sponsors in Manchester")
    expect(page).to have_link("Amazon UK Services")

    # Click on the company link
    click_link "Amazon UK Services"

    # Verify company detail page loads
    expect(page).to have_current_path(company_path(company))
    expect(page).to have_content("Amazon UK Services")
    expect(page).to have_content("Active Sponsor")
    expect(page).to have_content("Skilled Worker")
  end
end
