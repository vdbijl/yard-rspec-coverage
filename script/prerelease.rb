# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# The checks of `rake prerelease`, which has the tasks. Not part of the gem.
module Prerelease
  GEMSPEC = 'yard-rspec-coverage.gemspec'
  FIXTURE = 'spec/fixtures/lenient_minimum'

  # @return [<String>] What the built gem must contain.
  REQUIRED_FILES = %w[lib/yard-rspec-coverage.rb lib/yard_rspec/handler.rb lib/tasks/yard_rspec.rake
                      templates/default/method_details/html/rspec_specs.erb
                      templates/default/fulldoc/html/css/rspec.css
                      templates/default/fulldoc/html/js/rspec.js
                      README.md CHANGELOG.md LICENSE].freeze

  # @return [Regexp] What the built gem must not contain.
  UNWANTED_PATTERN = %r{\A(spec|script|doc_templates|\.github)/|\A\.}

  # Prints the problems and stops the task, if there are any.
  # @param [<String>] problems
  def self.fail_on(problems)
    return if problems.empty?

    abort(problems.map {|problem| "  - #{problem}"}.unshift('Prerelease check failed:').join("\n"))
  end

  # @return [<String>] What is wrong with the repository as a release commit.
  def self.repository_problems
    version = Gem::Specification.load(GEMSPEC).version
    problems = []
    problems << 'the working tree has uncommitted changes' if !`git status --porcelain`.empty?
    problems.concat(version_problems(version))
    problems.concat(changelog_problems(version))
  end

  # @return [<String>]
  def self.version_problems(version)
    tags = `git tag --list 'v*'`.split.map {|tag| Gem::Version.new(tag.delete_prefix('v'))}
    latest = tags.max
    return [] if latest.nil? || version > latest

    ["version #{version} is not newer than the latest tag v#{latest}"]
  end
  private_class_method :version_problems

  # @return [<String>]
  def self.changelog_problems(version)
    changelog = File.read('CHANGELOG.md')
    problems = []
    if !changelog.match?(/^## #{version}\b/)
      problems << "CHANGELOG.md has no '## #{version}' heading"
    end
    problems << "CHANGELOG.md has a '## Unreleased' heading" if changelog.match?(/^## Unreleased/)
    problems
  end
  private_class_method :changelog_problems

  # @return [<String>] What is wrong with the built gem.
  def self.package_problems
    Dir.mktmpdir('prerelease') do |dir|
      gem_file = File.join(dir, 'plugin.gem')
      output, status = Open3.capture2e('gem', 'build', GEMSPEC, '--output', gem_file)
      next ["gem build failed:\n#{output}"] if !status.success?

      unpacked = unpack(gem_file, dir)
      content_problems(unpacked) + packaged_plugin_problems(unpacked, dir)
    end
  end

  # @return [String] The directory with the files of the gem.
  def self.unpack(gem_file, dir)
    system('gem', 'unpack', gem_file, '--target', dir, out: File::NULL) or abort 'gem unpack failed'
    File.join(dir, File.basename(gem_file, '.gem'))
  end
  private_class_method :unpack

  # @return [<String>]
  def self.content_problems(unpacked)
    files = Dir.glob('**/*', File::FNM_DOTMATCH, base: unpacked).select {|f| File.file?("#{unpacked}/#{f}")}
    (REQUIRED_FILES - files).map {|file| "the gem lacks #{file}"} +
      files.grep(UNWANTED_PATTERN).map {|file| "the gem contains #{file}"}
  end
  private_class_method :content_problems

  # Runs `yard doc` with only the unpacked gem on the load path, so the repository's own lib/ and
  # templates/ cannot hide a file that is missing from the gem.
  # @return [<String>]
  def self.packaged_plugin_problems(unpacked, dir)
    html = File.join(dir, 'html')
    status = yard_doc(File.join(unpacked, 'lib'), html)
    if !status.success?
      return ["yard doc with the packaged plugin failed (exit #{status.exitstatus})"]
    end
    return [] if File.read(File.join(html, 'Widget.html')).include?('RSpec Examples')

    ['the packaged plugin adds no examples to the HTML']
  end
  private_class_method :packaged_plugin_problems

  # @return [Process::Status]
  def self.yard_doc(lib_dir, output_dir)
    Bundler.with_unbundled_env do
      Open3.capture2e({ 'RUBYLIB' => lib_dir }, 'yard', 'doc', '--plugin', 'rspec-coverage',
                      '--quiet', '--no-save', '--output-dir', output_dir, 'lib', 'spec',
                      chdir: File.expand_path(FIXTURE)).last
    end
  end
  private_class_method :yard_doc

  # Stops the task if mutaruby is missing or mutants survive.
  def self.mutation_testing
    system('mutaruby', '--version', out: File::NULL) or
      abort 'mutaruby is not installed: run bundle install'
    system('mutaruby', '--test', 'bundle exec rspec', '--coverage', '--strict-ignore',
           '--fail-under', '100',
           'lib/**/*.rb', 'templates/**/*.rb') or abort 'Mutation testing found surviving mutants'
  end

  # Prints the comparison with RSpec for a person to read; skipped without COMPARE_PROJECT.
  def self.compare_with_rspec
    project = ENV.fetch('COMPARE_PROJECT', nil)
    if project.nil?
      return puts('SKIPPED the comparison with RSpec: set COMPARE_PROJECT (and COMPARE_RSPEC).')
    end

    system('ruby', 'script/compare_with_rspec/run.rb', project,
           ENV.fetch('COMPARE_RSPEC', 'bundle exec rspec')) or abort 'The comparison failed to run'
    puts 'Check the categories that need a look, see "Running checks" in AGENTS.md.'
  end
end
