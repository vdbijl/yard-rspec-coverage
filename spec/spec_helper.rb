# frozen_string_literal: true

# Started by `rake spec:coverage`. A run of only some of the specs would not meet the minimum.
if ENV['COVERAGE']
  require 'simplecov'
  SimpleCov.start do
    enable_coverage :branch
    skip '/spec/'
    minimum_coverage line: 99, branch: 100
  end
end

require 'yard'
require 'yard-rspec-coverage'

YARD::Logger.instance.level = YARD::Logger::ERROR

# Matchers for the examples that the plugin attaches, to compare their attributes.
module ExampleMatchers
  def an_example(description, code = '', pending: false)
    an_instance_of(YardRspec::Example)
      .and have_attributes(description:, code:, pending?: pending)
  end

  def an_example_group(description, *children)
    an_instance_of(YardRspec::ExampleGroup)
      .and have_attributes(description:, children: match(children))
  end
end

RSpec.configure do |config|
  config.include ExampleMatchers

  config.before do
    YARD::Registry.clear
  end

  # YARD catches an exception raised by a handler and only logs it, so the example would pass.
  config.before do
    @yard_errors = []
    allow(YARD::Logger.instance).to receive(:error) {|*message| @yard_errors << message.join(' ')}
  end

  config.after do
    expect(@yard_errors).to eq([]), "YARD logged errors: #{@yard_errors.join("\n")}"
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
