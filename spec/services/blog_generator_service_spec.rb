require "rails_helper"

RSpec.describe BlogGeneratorService do
  describe "Quality Gate Scoring" do
    let(:service) { described_class.new(topic: "Test Topic") }

    it "rejects articles containing banned AI slop phrases" do
      slop_json = {
        "title" => "Generic AI Post",
        "slug" => "generic-ai-post",
        "category" => "Immigration News",
        "meta_description" => "A summary",
        "key_takeaways" => ["Point 1"],
        "content_html" => "<h2>Introduction</h2><p>In today's fast-paced world, we must delve into the rich tapestry of immigration.</p><ul><li>Rule 1</li></ul>",
        "image_prompt" => "Illustration"
      }

      report = service.send(:evaluate_quality, slop_json)
      expect(report[:score]).to be < 80
      expect(report[:issues]).to include(a_string_matching("Banned phrase detected"))
    end

    it "passes high quality articles with data density and proper HTML elements" do
      high_quality_json = {
        "title" => "Home Office Enforcement Report 2026",
        "slug" => "home-office-enforcement-report-2026",
        "category" => "Compliance",
        "meta_description" => "Details on 2026 Home Office sponsor licence penalties.",
        "key_takeaways" => ["Takeaway 1"],
        "content_html" => <<~HTML,
          <h2>Executive Summary</h2>
          <p>On August 11, 2026, the Home Office reported issuing 1,420 civil penalties totaling £74 million under Paragraph SW 14.1 guidance. UK employers holding Skilled Worker sponsor licences must ensure ongoing compliance with key duties including right to work verification, record-keeping, and reporting worker absences within 10 working days. Failure to comply can result in severe financial penalties or licence revocation.</p>
          
          <h2>Key Employer Duties and Compliance Requirements</h2>
          <p>The Home Office has increased unannounced site visits in 2026. Inspectors will review employee records, organizational charts, and Certificate of Sponsorship (CoS) assignments. Employers must maintain evidence of recruitment, salary calculations, and qualification documents for at least 24 months or until the sponsor licence is surrendered.</p>
          
          <p>Additionally, Level 1 Users on the Sponsor Management System (SMS) are strictly required to log any changes in employee employment details within statutory timeframes. This includes salary reductions, promotions, change in work address, or termination of employment. Unreported changes constitute a breach of sponsor duties and are frequently cited in licence suspension letters.</p>

          <h2>Minimum Salary Threshold Updates for 2026</h2>
          <p>Effective April 2026, the general salary threshold for Skilled Worker sponsorship has been updated to £38,700 or the going rate for the relevant Standard Occupational Classification (SOC) code, whichever is higher. Employers extending existing visas under grandfathering provisions must comply with transition rules by April 2030.</p>
          
          <p>It is vital for compensation and benefits managers to cross-check payroll records against SOC codes on a quarterly basis. When minimum salary rules are updated by UKVI, sponsored employees whose pay falls below statutory rates must be adjusted accordingly before issuing defined or undefined Certificates of Sponsorship.</p>

          <h2>Detailed Guidelines on Right to Work Verification</h2>
          <p>Employers must perform online Right to Work checks using the Home Office share code portal for all non-UK nationals holding biometric residence permits or eVisa status. Manual document checks are only permitted for British and Irish citizens presenting original valid passports. Retaining clear, dated PDF copies of online share code profile checks is mandatory for all sponsors throughout the employment term and for two full years following employment termination.</p>

          <h2>Actionable Compliance Checklist</h2>
          <ul>
            <li>Conduct quarterly internal audits of all sponsored worker files and right to work checks.</li>
            <li>Ensure SMS Level 1 users report salary adjustments or job title changes within 10 working days.</li>
            <li>Maintain clear records of working hours and work locations for remote or hybrid staff.</li>
            <li>Verify that all sponsored employees are paid strictly via bank transfer matching payroll records.</li>
            <li>Review SOC code allocations against the updated 2026 Home Office occupation list.</li>
          </ul>
          
          <h2>Conclusion and Next Steps</h2>
          <p>Maintaining a clean compliance record is vital for keeping your Home Office sponsor licence active. By conducting regular internal reviews and staying updated with statutory rule updates, organizations can mitigate operational risks and protect their global workforce. Contact our compliance advisory team for a mock Home Office audit or licence review.</p>
        HTML
        "image_prompt" => "Chart illustration"
      }

      report = service.send(:evaluate_quality, high_quality_json)
      expect(report[:score]).to be >= 80
      expect(report[:issues]).to be_empty
    end
  end
end
