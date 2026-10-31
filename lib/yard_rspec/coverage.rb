# frozen_string_literal: true

module YardRspec
  # Which methods count for RSpec coverage.
  module Coverage
    # @return [Regexp] Spec and helper files, whose methods need no specs.
    SPEC_FILE_PATTERN = %r{(?:^|/)spec/|_spec\.rb$|_helper\.rb$}

    # @return [<YARD::CodeObjects::MethodObject>]
    def self.countable_methods
      YARD::Registry.all(:method).select {|method| countable?(method)}
    end

    # Attributes and aliases have no behaviour of their own to spec.
    # @param [YARD::CodeObjects::MethodObject] method
    # @return [Boolean]
    def self.countable?(method)
      method.visibility == :public &&
        !method.file.to_s.match?(SPEC_FILE_PATTERN) &&
        !method.is_attribute? &&
        !method.is_alias?
    end

    # Pending examples (`xit`) do not run, so they do not count.
    # @param [YARD::CodeObjects::MethodObject] method
    # @return [Boolean]
    def self.covered?(method)
      examples(method[:rspec_examples] || []).any? {|example| !example[:pending]}
    end

    # @param [<Hash>] nodes Example and context nodes, see `method[:rspec_examples]`.
    # @return [<Hash>] The examples at any depth.
    def self.examples(nodes)
      nodes.flat_map {|node| node[:children] ? examples(node[:children]) : [node]}
    end
  end
end
