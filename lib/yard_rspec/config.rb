# frozen_string_literal: true

# The yard-rspec-coverage plugin.
module YardRspec
  # Set in a project's Rakefile, e.g. `YardRspec::Config.minimum_rspec_coverage = 80.0`.
  module Config
    DEFAULT_MINIMUM_RSPEC_COVERAGE = 100.0 #: Float

    DEFAULT_FILES = ['{lib,spec}/**/*.rb'].freeze #: Array[String]

    @minimum_rspec_coverage = DEFAULT_MINIMUM_RSPEC_COVERAGE
    @files = DEFAULT_FILES

    # @rbs minimum_rspec_coverage: Float -- A percentage.
    # @rbs return: Float
    def self.minimum_rspec_coverage=(minimum_rspec_coverage)
      @minimum_rspec_coverage = minimum_rspec_coverage
    end

    # @rbs files: Array[String] -- Glob patterns.
    # @rbs return: Array[String]
    def self.files=(files)
      @files = files
    end

    # @rbs return: Float -- A percentage, by default DEFAULT_MINIMUM_RSPEC_COVERAGE.
    def self.minimum_rspec_coverage
      @minimum_rspec_coverage
    end

    # @rbs return: Array[String] -- Glob patterns of the source and spec files, by default
    #   DEFAULT_FILES.
    def self.files
      @files
    end
  end
end
