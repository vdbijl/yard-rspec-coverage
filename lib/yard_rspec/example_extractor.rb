# frozen_string_literal: true

module YardRspec
  # Extracts the RSpec examples of a describe block as a tree of example and context nodes.
  # Excluded examples (xit/xspecify/xexample) get `pending: true`.
  class ExampleExtractor
    # @return [<String>] The keywords of examples that RSpec runs.
    EXAMPLE_KEYWORDS = %w[it specify example].freeze

    # @return [<String>] The keywords of examples that RSpec excludes from the run.
    PENDING_KEYWORDS = %w[xit xspecify xexample].freeze

    # @param [YARD::Parser::Ruby::AstNode, nil] block_node The body of a describe block.
    def initialize(block_node)
      @block_node = block_node
    end

    # @return [<Hash>] The example and context nodes.
    def extract
      return [] if @block_node.nil?

      examples = []
      traverse(@block_node, examples)
      examples
    end

    private

    def traverse(node, nodes)
      return if !ast_node?(node)

      if example_call?(node)
        nodes << build_example(node)
      elsif context_call?(node)
        add_context(node, nodes)
      else
        node.children.each {|child| traverse(child, nodes)}
      end
    end

    # A context without examples is left out.
    def add_context(node, nodes)
      children = []
      traverse(node.last&.last, children)
      return if children.empty?

      nodes << { description: extract_context_description(node), children: children }
    end

    # Includes the `x` variants.
    # @return [Boolean]
    def example_call?(node)
      return false if node.type != :command

      name_node = node.children[0]
      name_node&.type == :ident && (EXAMPLE_KEYWORDS + PENDING_KEYWORDS).include?(name_node.source)
    end

    # @return [Boolean]
    def context_call?(node)
      return false if node.type != :command

      name_node = node.children[0]
      name_node&.type == :ident && %w[context describe].include?(name_node.source)
    end

    # @return [String, nil]
    def extract_context_description(node)
      find_string_literal(node.parameters.first)
    end

    # @return [Hash] With `pending: true` only for the `x` variants.
    def build_example(node)
      example = {
        description: extract_description(node.children[1]) || 'example',
        code: extract_code(node.children[2])
      }
      example[:pending] = true if PENDING_KEYWORDS.include?(node.children[0].source)
      example
    end

    # @return [String, nil]
    def extract_description(args_node)
      return nil if !ast_node?(args_node)

      find_string_literal(args_node)
    end

    # @return [String, nil] The first one at any depth.
    def find_string_literal(node)
      return nil if !ast_node?(node)
      return extract_string_content(node) if node.type == :string_literal

      node.children.each do |child|
        result = find_string_literal(child)
        return result if result
      end
      nil
    end

    # @return [String, nil]
    def extract_string_content(string_literal_node)
      string_literal_node.children.each do |child|
        next if !ast_node?(child) || child.type != :string_content

        child.children.each do |grandchild|
          return grandchild.source if grandchild.is_a?(YARD::Parser::Ruby::AstNode) &&
                                      grandchild.type == :tstring_content
        end
      end
      nil
    end

    # @return [String]
    def extract_code(block_node)
      return '' if !ast_node?(block_node)
      return '' if !%i[do_block brace_block].include?(block_node.type)

      body = block_node.children.first
      return '' if !ast_node?(body)

      # The source starts at the first token; restore its indentation before dedenting.
      dedent((' ' * column_of(body)) + body.source.strip)
    end

    # @return [Integer] 0 if unknown.
    def column_of(node)
      file_source = node.full_source
      start = node.source_range&.first
      return 0 if file_source.nil? || start.nil? || start.zero?

      newline_before = file_source.rindex("\n", start - 1)
      newline_before.nil? ? start : start - newline_before - 1
    end

    # @return [Boolean]
    def ast_node?(node)
      node.is_a?(YARD::Parser::Ruby::AstNode)
    end

    # @return [String]
    def dedent(source)
      lines = source.lines.map(&:rstrip)
      min_indent = lines.reject(&:empty?).map {|line| line[/^\s*/].length}.min || 0
      lines.map {|line| line[min_indent..] || line}.join("\n").strip
    end
  end
end
