# frozen_string_literal: true

require 'open3'
require 'bundler/audit/task'
require 'rspec/core/rake_task'
require_relative 'lib/yard_rspec/rake_tasks'
YardRspec::Config.minimum_rspec_coverage = 100.0
YardRspec::Config.files = ['{lib,spec}/**/*.rb']

RSpec::Core::RakeTask.new('rspec') do |task|
  task.verbose = false # Hides the long ruby command line.
end

# check Gemfile.lock against the advisory database
Bundler::Audit::Task.new

require 'rubocop/rake_task'
RuboCop::RakeTask.new

namespace :spec do
  desc 'Run the specs with SimpleCov, which fails below the minimum set in spec/spec_helper.rb'
  task :coverage do
    ENV['COVERAGE'] = 'true'
    Rake::Task[:rspec].invoke
  end
end

namespace :yard do
  desc 'Verify that all code objects are documented, without YARD warnings'
  task :coverage do
    output, status = Open3.capture2e('yard', 'stats', '--list-undoc', '--fail-on-warning')
    percentage = output[/([\d.]+)% documented/, 1].to_f
    if !status.success? || percentage < 100.0
      puts output
      abort 'YARD documentation coverage is below 100%.'
    end

    # yard:doc prints the full statistics.
    puts format('YARD documentation coverage: %<percentage>.2f%%', percentage:)
  end
end

desc 'Run all checks: RuboCop, dependency audit, RSpec with coverage, and YARD coverage'
task default: %i[rubocop bundle:audit spec:coverage yard:coverage yard:rspec_coverage]
