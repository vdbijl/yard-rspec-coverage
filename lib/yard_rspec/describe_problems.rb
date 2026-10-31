# frozen_string_literal: true

module YardRspec
  # Describe blocks naming a class or method that cannot be found. Not logged as YARD warnings,
  # which would fail `yard --fail-on-warning`; `yard:rspec_coverage` lists them instead.
  # Kept on the registry root, so YARD::Registry.clear also clears them.
  module DescribeProblems
    # @return [Symbol]
    REGISTRY_KEY = :rspec_describe_problems

    # @param [String] problem The location and description of the problem, for example
    #   "spec/widget_spec.rb:4: could not find method '#wobble' on 'Widget'".
    def self.add(problem)
      root = YARD::Registry.root
      root[REGISTRY_KEY] ||= []
      root[REGISTRY_KEY] << problem
    end

    # @return [<String>] Sorted by location.
    def self.all
      (YARD::Registry.root[REGISTRY_KEY] || []).sort
    end
  end
end
