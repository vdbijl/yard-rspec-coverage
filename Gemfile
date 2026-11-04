# frozen_string_literal: true

source 'https://rubygems.org'

gemspec

group :development do
  gem 'bundler-audit', '>= 0.9'
  gem 'mutaruby', '>= 0.3' # Mutation testing, see rake prerelease:mutation
  gem 'rake', '>= 12.0'
  gem 'redcarpet', '>= 3.4' # Markdown for YARD, see .yardopts
  gem 'rspec', '>= 3.0'
  # Minimum versions for the `plugins:` key in .rubocop.yml.
  gem 'rubocop', '>= 1.72'
  gem 'rubocop-performance', '>= 1.24'
  gem 'rubocop-rake', '>= 0.7'
  gem 'rubocop-rspec', '>= 3.5'
  gem 'simplecov', '>= 1.0.3' # For SimpleCov.skip
  gem 'steep', '>= 2.1' # Checks the inline RBS annotations, see Steepfile
  gem 'yard-inline-rbs', '~> 0.1' # Documents the inline RBS annotations, see .yardopts
end
