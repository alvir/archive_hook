require "bundler/setup"
require "logger" # newer concurrent-ruby no longer requires this, but activesupport needs it loaded
require "archive_hook"

RSpec::Matchers.define_negated_matcher :not_change, :change

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
