RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the test framework
  # you're using (MiniTest) if you prefer.
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here.
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Shared context metadata behaviour
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # Run specs in random order to surface hidden dependencies.
  config.order = :random
  Kernel.srand config.seed

  # Allow focus filtering with :focus tag
  config.filter_run_when_matching :focus

  # Formatter
  config.default_formatter = 'doc' if config.files_to_run.one?
end
