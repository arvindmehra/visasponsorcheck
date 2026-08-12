require "rails_helper"

RSpec.describe WeeklyBlogIngestionJob, type: :job do
  it "calls BlogGeneratorService when performed" do
    expect(BlogGeneratorService).to receive(:call).and_return({
      success: true,
      blog: instance_double(Blog, title: "Test Blog"),
      quality_report: { score: 95 }
    })

    described_class.new.perform
  end
end
