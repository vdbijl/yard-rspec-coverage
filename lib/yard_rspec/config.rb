# frozen_string_literal: true

# The yard-rspec-coverage plugin.
module YardRspec
  # Set in a project's Rakefile, e.g. `YardRspec::Config.minimum_rspec_coverage = 80.0`.
  module Config
    class << self
      attr_writer :minimum_rspec_coverage, :files

      # @return [Float] A percentage.
      def minimum_rspec_coverage
        @minimum_rspec_coverage || DEFAULT_MINIMUM_RSPEC_COVERAGE
      end

      # @return [<String>] Glob patterns of the source and spec files.
      def files
        @files || DEFAULT_FILES
      end
    end

    # @return [Float]
    DEFAULT_MINIMUM_RSPEC_COVERAGE = 100.0

    # @return [<String>]
    DEFAULT_FILES = ['{lib,spec}/**/*.rb'].freeze
  end
end
