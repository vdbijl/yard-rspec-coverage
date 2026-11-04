# frozen_string_literal: true

require_relative 'prerelease'

# The checks to run on the release commit, before tagging. They take several minutes, so they are
# not part of the default task. Not part of the gem.
#
#   bundle exec rake prerelease
#   COMPARE_PROJECT=../other-project COMPARE_RSPEC="rvm ruby-3.3@other do bundle exec rspec" \
#     bundle exec rake prerelease
namespace :prerelease do
  desc 'Check that the repository is a release commit: clean, new version, changelog entry'
  task :repository do
    Prerelease.fail_on(Prerelease.repository_problems)
  end

  desc 'Check that the built gem has the right files and works without the repository'
  task :package do
    Prerelease.fail_on(Prerelease.package_problems)
  end

  desc 'Mutation testing with the ignore list; needs the mutaruby gem, takes several minutes'
  task :mutation do
    Prerelease.mutation_testing
  end

  desc 'Compare with rspec --dry-run in COMPARE_PROJECT using COMPARE_RSPEC; for a person to read'
  task :compare do
    Prerelease.compare_with_rspec
  end
end

desc 'All checks before a release: repository, package, mutation testing, comparison'
task prerelease: %w[prerelease:package prerelease:mutation prerelease:compare prerelease:repository]
