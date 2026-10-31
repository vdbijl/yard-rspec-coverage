# frozen_string_literal: true

# Defines the yard:doc and yard:rspec_coverage Rake tasks. Usage in a Rakefile:
#
#   require 'yard_rspec/rake_tasks'
#   YardRspec::Config.minimum_rspec_coverage = 80.0
require 'rake'

load File.expand_path('../tasks/yard_rspec.rake', __dir__)
