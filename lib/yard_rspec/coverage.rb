# frozen_string_literal: true

module YardRspec
  # Which methods count for RSpec coverage.
  module Coverage
    # Files in a spec directory or ending in _spec.rb. Not any _helper.rb, which would include
    # Rails view helpers.
    SPEC_FILE_PATTERN = %r{(?:^|/)spec/|_spec\.rb$} #: Regexp

    # @rbs file: String
    # @rbs return: bool -- Whether the file is spec code, which needs no specs and no documentation.
    def self.spec_file?(file)
      file.match?(SPEC_FILE_PATTERN)
    end

    # @rbs return: Array[YARD::CodeObjects::MethodObject] -- The methods that need specs, see
    #   {countable?}.
    def self.countable_methods
      YARD::Registry.all(:method).select {|method| countable?(method)}
    end

    # @rbs method: YARD::CodeObjects::MethodObject
    # @rbs return: bool -- True for a public method outside spec files. Attributes and aliases are
    #   left out: they have no behavior of their own.
    def self.countable?(method)
      method.visibility == :public &&
        !spec_file?(method.file.to_s) &&
        !method.is_attribute? &&
        !method.is_alias?
    end

    # @rbs method: YARD::CodeObjects::MethodObject
    # @rbs return: bool -- Whether it has an example that is not pending: `xit` does not run.
    def self.covered?(method)
      examples(method[:rspec_examples] || []).any? {|example| !example.pending?}
    end

    # @rbs nodes: Array[example_node] -- Examples and example groups, see `method[:rspec_examples]`.
    # @rbs return: Array[Example] -- The examples at any depth.
    def self.examples(nodes)
      nodes.flat_map(&:examples)
    end
  end
end
