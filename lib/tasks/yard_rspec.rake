# frozen_string_literal: true

# The tasks load the plugin when they run; loading it here would affect every YARD run in Rake.
require 'yard'
require_relative '../yard_rspec/config'
require_relative '../yard_rspec/task_reports'

namespace :yard do
  desc 'Generate YARD documentation with the yard-rspec-coverage plugin'
  task :doc do
    # YARD ignores --plugin in-process.
    require_relative '../yard-rspec-coverage'
    YARD::CLI::Yardoc.run(*YardRspec::Config.files)
  end

  desc 'Verify RSpec coverage of public methods (without attributes and aliases)'
  task :rspec_coverage do
    require_relative '../yard-rspec-coverage'
    YARD::Registry.clear
    yardoc = YardRspec::TaskReports.yardoc_with_yardopts(YardRspec::Config.files)
    YARD.parse(yardoc.files, yardoc.excluded, YARD::Logger::ERROR)

    coverage = YardRspec::TaskReports.rspec_coverage(YardRspec::Coverage.countable_methods)
    YardRspec::TaskReports.describe_problems(YardRspec::DescribeProblems.all)
    minimum = YardRspec::Config.minimum_rspec_coverage

    if coverage < minimum
      warn format("\nRSpec coverage too low: %<coverage>.2f%% (minimum is %<minimum>.2f%%)",
                  coverage: coverage.floor(2), minimum:)
      exit 1
    end
  end
end
