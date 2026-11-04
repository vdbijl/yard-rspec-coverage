# frozen_string_literal: true

module YardRspec
  # Describe blocks naming a class or method that cannot be found. Not logged as YARD warnings,
  # which would fail `yard --fail-on-warning`; `yard:rspec_coverage` lists them instead.
  # Kept on the registry root, so YARD::Registry.clear also clears them.
  module DescribeProblems
    REGISTRY_KEY = :rspec_describe_problems #: Symbol

    # @rbs problem: String -- The location and description of the problem, for example
    #   "spec/widget_spec.rb:4: could not find method '#wobble' on 'Widget'".
    # @rbs return: nil
    def self.add(problem)
      root = YARD::Registry.root
      root[REGISTRY_KEY] ||= []
      root[REGISTRY_KEY] << problem
      nil
    end

    # @rbs return: Array[String] -- Sorted by location.
    def self.all
      (YARD::Registry.root[REGISTRY_KEY] || []).sort
    end

    # Records an error as a problem instead of letting YARD log it, so the parse goes on.
    # @rbs location: String -- 'file:line' of the describe.
    # @yield The code of the describe that may fail.
    # @rbs &block: () -> void
    # @rbs return: void
    def self.recording_failure(location)
      yield
    rescue StandardError => e
      add("#{location}: could not process the describe: #{e.class}: #{e.message}")
    end
  end
end
