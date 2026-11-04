# frozen_string_literal: true

# Compares the examples the plugin attaches to methods with the examples RSpec finds in a dry run
# of another project. Specs only check what we think RSpec does; this checks it on real specs.
#
#   bundle exec ruby script/compare_with_rspec/run.rb PROJECT_DIR [RSPEC_COMMAND]
#
# RSPEC_COMMAND runs RSpec in PROJECT_DIR with that project's own Ruby and gems, for example
# "rvm ruby-3.3@other-gemset do bundle exec rspec" (default: "bundle exec rspec").
# The dry run loads the spec files, so it runs their top-level code, but no examples. The full
# report goes to a temporary directory, whose path is printed at the end.

require 'json'
require 'open3'
require 'shellwords'
require 'tmpdir'
require_relative '../../lib/yard-rspec-coverage'

module YardRspecCompare
  # The examples RSpec finds in a dry run of the project.
  module RspecExamples
    # @return [<Hash>] See ExampleLister#example_hash.
    def self.list(project_dir, rspec_command, out_dir)
      out = File.join(out_dir, 'rspec.json')
      output, status = unbundled do
        Open3.capture2e({ 'EXAMPLE_LIST_OUT' => out }, dry_run(rspec_command), chdir: project_dir)
      end
      # The project's own at_exit hooks, such as SimpleCov, may fail after the list is written.
      if !File.exist?(out)
        abort "RSpec wrote no example list (exit #{status.exitstatus}):\n"\
              "#{output[-3000..] || output}"
      end

      JSON.parse(File.read(out), symbolize_names: true)
    end

    def self.dry_run(rspec_command)
      lister = File.expand_path('example_lister.rb', __dir__)
      "#{rspec_command} --dry-run --require #{lister.shellescape} "\
        '--format YardRspecCompare::ExampleLister'
    end
    private_class_method :dry_run

    # Without this project's Bundler settings, so the project uses its own Gemfile.
    def self.unbundled(&)
      defined?(Bundler) ? Bundler.with_unbundled_env(&) : yield
    end
    private_class_method :unbundled
  end

  # The examples the plugin attaches when it parses the project's lib/, app/ and spec/ files.
  module PluginExamples
    # An example that knows where its `it` is, to match it with RSpec's examples.
    class LocatedExample < YardRspec::Example
      attr_reader :file

      attr_reader :line

      def initialize(example, file, line)
        super(description: example.description, code: example.code, pending: example.pending?)
        @file = file
        @line = line
      end
    end

    # Makes the extractor build LocatedExamples.
    module Location
      private

      def build_example(node)
        LocatedExample.new(super, File.expand_path(node.file), node.line)
      end
    end

    # @return [{examples: <Hash>, problems: <String>, errors: <String>}] Each example has the
    #   :method it is attached to.
    def self.list(project_dir)
      YardRspec::ExampleExtractor.prepend(Location)
      # Keeps the methods of spec support files, whose examples RSpec finds too.
      YardRspec::SpecObjects.define_singleton_method(:remove) {nil}
      errors = []
      YARD::Logger.instance.define_singleton_method(:error) {|*message| errors << message.join(' ')}
      YARD.parse(ruby_files(project_dir), [], YARD::Logger::FATAL)
      { examples: attached_examples, problems: YardRspec::DescribeProblems.all, errors: errors }
    end

    def self.ruby_files(project_dir)
      Dir[File.join(project_dir, '{lib,app,spec}/**/*.rb')]
        .reject {|file| file.include?('/vendor/')}
    end
    private_class_method :ruby_files

    def self.attached_examples
      YARD::Registry.all(:method).flat_map do |method|
        YardRspec::Coverage.examples(method[:rspec_examples] || []).map do |example|
          { description: example.description, pending: example.pending?, method: method.path,
            file: example.file, line: example.line }
        end
      end
    end
    private_class_method :attached_examples
  end

  # Sorts the differences between RSpec's and the plugin's examples into categories.
  class Comparison
    # @return [<String>] The categories that need a look; the others are expected.
    SUSPICIOUS = ['MISSED in a method describe', 'description differs', 'pending differs',
                  'plugin only'].freeze

    # @return [{String => <String>}]
    attr_reader :categories

    def initialize(rspec_examples, plugin, project_dir)
      @plugin_examples = plugin[:examples].group_by {|example| key(example)}
      @rspec_keys = rspec_examples.to_h {|example| [key(example), true]}
      @root = "#{File.expand_path(project_dir)}/"
      @categories = Hash.new {|hash, name| hash[name] = []}
      rspec_examples.each {|example| compare(example)}
      plugin[:examples].reject {|example| @rspec_keys[key(example)]}.each do |example|
        @categories['plugin only'] <<
          "#{location(example)}  #{example[:method]} > #{example[:description]}"
      end
    end

    private

    def key(example)
      [example[:file], example[:line]]
    end

    def location(example)
      "#{example[:file].delete_prefix(@root)}:#{example[:line]}"
    end

    def compare(example)
      found = @plugin_examples[key(example)]
      if !found
        @categories[missing_category(example)] << "#{location(example)}  #{path(example)}"
        return
      end

      @categories['matched'] << location(example)
      found.each {|plugin_example| compare_attributes(example, plugin_example)}
    end

    def missing_category(example)
      if example[:groups].flatten.none? {|argument| argument.start_with?('#', '.')}
        'not in a method describe'
      elsif example[:shared_group]
        'from a shared example group (it_behaves_like)'
      else
        'MISSED in a method describe'
      end
    end

    def compare_attributes(example, plugin_example)
      if plugin_example[:description] != example[:description]
        @categories['description differs'] <<
          "#{location(example)}  rspec=#{example[:description].inspect} "\
          "plugin=#{plugin_example[:description].inspect}"
      end
      plugin_pending = plugin_example[:pending]
      return if plugin_pending == example[:pending]

      @categories['pending differs'] <<
        "#{location(example)}  rspec=#{example[:pending]} plugin=#{plugin_pending}"
    end

    def path(example)
      groups = example[:groups].map {|arguments| arguments.join(', ')}
      "#{groups.join(' > ')} > #{example[:description]}"
    end
  end

  # Prints the counts and the first entries of each category, and writes the full report.
  module Report
    # @return [Integer]
    SHOWN = 10

    # @param [Comparison] comparison
    # @param [{examples: <Hash>, problems: <String>, errors: <String>}] plugin
    def self.print(comparison, plugin, out_dir)
      full = File.join(out_dir, 'report.txt')
      File.open(full, 'w') do |file|
        comparison.categories.sort.each {|name, entries| print_category(file, name, entries)}
        file.puts('describe problems:', plugin[:problems].map {|problem| "  #{problem}"})
      end
      puts "describe problems: #{plugin[:problems].size}, YARD errors: #{plugin[:errors].size}"
      puts "full report: #{full}"
    end

    def self.print_category(file, name, entries)
      suspicious = Comparison::SUSPICIOUS.include?(name)
      puts "#{name}: #{entries.size}#{' (expected)' if !suspicious}"
      file.puts("#{name}: #{entries.size}", entries.map {|entry| "  #{entry}"})
      return if !suspicious

      entries.first(SHOWN).each {|entry| puts "    #{entry}"}
    end
    private_class_method :print_category
  end
end

if $PROGRAM_NAME == __FILE__
  project_dir = File.expand_path(ARGV.fetch(0) {abort 'Usage: run.rb PROJECT_DIR [RSPEC_COMMAND]'})
  out_dir = Dir.mktmpdir('compare_with_rspec')
  rspec_command = ARGV.fetch(1, 'bundle exec rspec')
  rspec_examples = YardRspecCompare::RspecExamples.list(project_dir, rspec_command, out_dir)
  plugin = YardRspecCompare::PluginExamples.list(project_dir)
  comparison = YardRspecCompare::Comparison.new(rspec_examples, plugin, project_dir)
  YardRspecCompare::Report.print(comparison, plugin, out_dir)
end
