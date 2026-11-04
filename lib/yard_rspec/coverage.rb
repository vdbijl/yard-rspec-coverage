# frozen_string_literal: true

module YardRspec
  # Which methods count for RSpec coverage.
  module Coverage
    # @return [Regexp] Files in a spec directory or ending in _spec.rb. Not any _helper.rb, which
    #   would include Rails view helpers.
    SPEC_FILE_PATTERN = %r{(?:^|/)spec/|_spec\.rb$}

    # @param [String] file
    # @return [Boolean] Whether the file is spec code, which needs no specs and no documentation.
    def self.spec_file?(file)
      file.match?(SPEC_FILE_PATTERN)
    end

    # @return [<YARD::CodeObjects::MethodObject>] The methods that need specs, see {countable?}.
    def self.countable_methods
      YARD::Registry.all(:method).select {|method| countable?(method)}
    end

    # @param [YARD::CodeObjects::MethodObject] method
    # @return [Boolean] True for a public method outside spec files. Attributes and aliases are
    #   left out: they have no behaviour of their own.
    def self.countable?(method)
      method.visibility == :public &&
        !spec_file?(method.file.to_s) &&
        !method.is_attribute? &&
        !method.is_alias?
    end

    # @param [YARD::CodeObjects::MethodObject] method
    # @return [Boolean] Whether it has an example that is not pending: `xit` does not run.
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
