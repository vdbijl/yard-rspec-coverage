# frozen_string_literal: true

Gem::Specification.new do |s|
  s.name        = 'yard-rspec-coverage'
  s.version     = '0.1.3'
  s.summary     = 'YARD plugin to display RSpec examples in documentation and report RSpec coverage'
  s.description = 'A YARD plugin that embeds RSpec examples alongside method documentation, ' \
                  'and reports public methods without specs'
  s.authors     = ['vdbijl']
  s.files       = Dir['lib/**/*', 'templates/**/*', 'README.md', 'CHANGELOG.md', 'LICENSE']
  s.homepage    = 'https://github.com/vdbijl/yard-rspec-coverage'
  s.license     = 'MIT'
  s.required_ruby_version = '>= 3.3'

  s.add_dependency 'yard', '~> 0.9'
  s.metadata['rubygems_mfa_required'] = 'true'
  s.metadata['source_code_uri'] = s.homepage
  s.metadata['changelog_uri'] = "#{s.homepage}/blob/main/CHANGELOG.md"
  s.metadata['bug_tracker_uri'] = "#{s.homepage}/issues"
end
