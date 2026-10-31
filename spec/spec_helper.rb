# frozen_string_literal: true

# Started by `rake spec:coverage`. A run of only some of the specs would not meet the minimum.
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    skip '/spec/'
    minimum_coverage line: 99, branch: 73
  end
end

require 'yard'
require 'yard-rspec-coverage'

YARD::Logger.instance.level = YARD::Logger::ERROR

RSpec.configure do |config|
  config.before do
    YARD::Registry.clear
  end

  config.raise_errors_for_deprecations!
  config.example_status_persistence_file_path = 'coverage/rspec_example_statuses.txt'
  config.disable_monkey_patching!
  config.order = :random

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
    mocks.verify_doubled_constant_names = true
  end
end
