# frozen_string_literal: true

# The tasks load the plugin when they run; loading it here would affect every YARD run in Rake.
require 'yard'
require_relative '../yard_rspec/config'

# @param [<YARD::CodeObjects::MethodObject>] uncovered
def uncovered_methods_report(uncovered)
  return if uncovered.empty?

  puts "\nMethods without RSpec specs:"
  uncovered.sort_by(&:path).each do |method|
    puts "  #{method.file}:#{method.line}: #{method.path}"
  end
end

# @param [<YARD::CodeObjects::MethodObject>] public_lib_methods
# @return [Float] The coverage percentage.
def rspec_coverage_report(public_lib_methods)
  total     = public_lib_methods.size
  uncovered = public_lib_methods.reject {|method| YardRspec::Coverage.covered?(method)}
  covered   = total - uncovered.size
  coverage  = total.positive? ? (covered.to_f / total * 100).round(2) : 100.0

  puts format('RSpec coverage: %<covered>d/%<total>d (%<coverage>.2f%%)',
              covered:, total:, coverage:)
  uncovered_methods_report(uncovered)

  coverage
end

# Applies .yardopts like `yard doc` does, so --exclude works. --no-output skips the markup check.
# @param [<String>] files Glob patterns; they replace the files in .yardopts.
# @return [YARD::CLI::Yardoc]
def yardoc_with_yardopts(files)
  yardoc = YARD::CLI::Yardoc.new
  yardoc.parse_arguments('--no-output', *files)
  yardoc
end

# These do not fail the coverage check.
# @param [<String>] describe_problems
def describe_problems_report(describe_problems)
  return if describe_problems.empty?

  puts "\nDescribe blocks without a matching class or method:"
  describe_problems.each {|describe_problem| puts "  #{describe_problem}"}
end

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
    yardoc = yardoc_with_yardopts(YardRspec::Config.files)
    YARD.parse(yardoc.files, yardoc.excluded, YARD::Logger::ERROR)

    coverage = rspec_coverage_report(YardRspec::Coverage.countable_methods)
    describe_problems_report(YardRspec::DescribeProblems.all)
    minimum = YardRspec::Config.minimum_rspec_coverage

    if coverage < minimum
      warn format("\nRSpec coverage too low: %<coverage>.2f%% (minimum is %<minimum>.2f%%)",
                  coverage:, minimum:)
      exit 1
    end
  end
end
