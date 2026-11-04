# frozen_string_literal: true

module YardRspec
  # The output and options of the `yard:rspec_coverage` task. Not loaded into the global namespace
  # by the rake file, since that would add the methods to every Rakefile that uses the plugin.
  module TaskReports
    # @rbs uncovered: Array[YARD::CodeObjects::MethodObject]
    # @rbs return: void
    def self.uncovered_methods(uncovered)
      return if uncovered.empty?

      puts "\nMethods without RSpec specs:"
      uncovered.sort_by(&:path).each do |method|
        puts "  #{method.file}:#{method.line}: #{method.path}"
      end
    end
    private_class_method :uncovered_methods

    # @rbs public_lib_methods: Array[YARD::CodeObjects::MethodObject]
    # @rbs return: Float -- The unrounded coverage percentage: rounding could pass a minimum of
    #   100. It is printed rounded down, so below 100 never shows as 100.00%.
    def self.rspec_coverage(public_lib_methods)
      total     = public_lib_methods.size
      uncovered = public_lib_methods.reject {|method| YardRspec::Coverage.covered?(method)}
      covered   = total - uncovered.size
      coverage  = total.positive? ? covered * 100.0 / total : 100.0

      puts format('RSpec coverage: %<covered>d/%<total>d (%<coverage>.2f%%)',
                  covered:, total:, coverage: coverage.floor(2))
      uncovered_methods(uncovered)

      coverage
    end

    # @rbs files: Array[String] -- Glob patterns; they replace the files in .yardopts, which YARD
    #   would otherwise add them to.
    # @rbs return: YARD::CLI::Yardoc -- With the options of .yardopts (so --exclude works) and no
    #   output.
    def self.yardoc_with_yardopts(files)
      yardoc = YARD::CLI::Yardoc.new
      yardoc.parse_arguments('--no-output')
      yardoc.files = files
      yardoc
    end

    # @rbs describe_problems: Array[String] -- Reported only; they do not fail the check.
    # @rbs return: void
    def self.describe_problems(describe_problems)
      return if describe_problems.empty?

      puts "\nDescribe blocks without a matching class or method:"
      describe_problems.each {|describe_problem| puts "  #{describe_problem}"}
    end
  end
end
