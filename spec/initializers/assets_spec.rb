require "rails_helper"

RSpec.describe "Asset Minification Inititalizer" do
  describe SimpleCssMinifier do
    let(:minifier) { SimpleCssMinifier.new(double("assembly")) }
    let(:raw_css) do
      <<-CSS
        /* This is a comment */
        body {
          background-color: white;
          color: #333;
        }

        h1 {
          margin: 10px 0px;
        }
      CSS
    end

    before do
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it "minifies CSS by stripping comments and compressing whitespaces" do
      compiled = minifier.compile("application.css", raw_css)
      expect(compiled).not_to include("This is a comment")
      expect(compiled).to eq("body{background-color:white;color:#333;}h1{margin:10px 0px;}")
    end

    it "does not minify when not in production environment" do
      allow(Rails.env).to receive(:production?).and_return(false)
      compiled = minifier.compile("application.css", raw_css)
      expect(compiled).to eq(raw_css)
    end
  end

  describe SimpleJsMinifier do
    let(:minifier) { SimpleJsMinifier.new(double("assembly")) }
    let(:raw_js) do
      <<-JS
        // This is a single-line comment
        const message = "Hello, World!"; // trailing comment
        const url = "https://example.com"; // protocol-relative shouldn't break

        /* Multi-line
           comment block */
        function greet(name) {
          console.log(message);
        }
      JS
    end

    before do
      allow(Rails.env).to receive(:production?).and_return(true)
    end

    it "minifies JS by removing comments and unnecessary whitespace while preserving lines" do
      compiled = minifier.compile("application.js", raw_js)
      expect(compiled).not_to include("This is a single-line comment")
      expect(compiled).not_to include("Multi-line")
      expect(compiled).to include('const message = "Hello, World!";')
      expect(compiled).to include('const url = "https://example.com";')
      expect(compiled).to include("function greet(name) {")
      expect(compiled).not_to include("  ") # indents should be stripped
    end

    it "does not minify when not in production environment" do
      allow(Rails.env).to receive(:production?).and_return(false)
      compiled = minifier.compile("application.js", raw_js)
      expect(compiled).to eq(raw_js)
    end
  end
end
