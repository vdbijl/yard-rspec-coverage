# frozen_string_literal: true

module YardRspec
  # Extracts the RSpec examples of a describe block as a tree of example and context nodes.
  # Excluded examples (xit/xspecify/xexample) get `pending: true`.
  class ExampleExtractor
    include AstHelpers

    # @return [<Symbol>] The keywords of examples that RSpec excludes from the run.
    PENDING_KEYWORDS = %i[xit xspecify xexample].freeze

    # @return [<Symbol>] The keywords of all examples, including the pending ones.
    KEYWORDS = (%i[it specify example] + PENDING_KEYWORDS).freeze

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
      if example_call?(node)
        nodes << build_example(node)
      elsif context_call?(node)
        add_context(node, nodes)
      else
        node.children.each {|child| traverse(child, nodes)}
      end
    end

    # A context without a block or without examples is left out.
    def add_context(node, nodes)
      block_body = block_body_of(node) or return
      children = []
      traverse(block_body, children)
      return if children.empty?

      nodes << { description: string_literal_text(node.parameters.first), children: children }
    end

    # @return [Boolean] Includes the `x` variants.
    def example_call?(node)
      node.type == :command && KEYWORDS.include?(node.method_name(true))
    end

    # @return [Boolean]
    def context_call?(node)
      node.type == :command && describe_or_context_call?(node)
    end

    # @return [Hash] With `pending: true` only for the `x` variants and examples without a block,
    #   which RSpec reports as pending.
    def build_example(node)
      example = {
        description: string_literal_text(node.parameters.first) || 'example',
        code: extract_code(block_body_of(node))
      }
      example[:pending] = true if pending_example?(node)
      example
    end

    # @return [Boolean]
    def pending_example?(node)
      PENDING_KEYWORDS.include?(node.method_name(true)) || block_body_of(node).nil?
    end

    # @param [YARD::Parser::Ruby::AstNode] argument The first argument of a call.
    # @return [String, nil] The text as written, so with interpolations such as `#{count}`; nil if
    #   empty or not a string literal, such as `format('runs %s', count)`.
    def string_literal_text(argument)
      text = string_text(argument)
      text if text && !text.empty?
    end

    # @return [String, nil] Nil when the node is not a string literal. Adjacent literals
    #   (`'runs ' \ 'twice'`) are joined, as RSpec sees them.
    def string_text(node)
      case node.type
      when :string_literal
        node.children.find {|child| child.type == :string_content}.children.map(&:source).join
      when :string_concat
        node.children.map {|child| string_text(child)}.join
      end
    end

    # @param [YARD::Parser::Ruby::AstNode, nil] block_body
    # @return [String] Empty without a block.
    def extract_code(block_body)
      return '' if block_body.nil?

      # The source starts at the first token; restore its indentation before dedenting.
      dedent((' ' * column_of(block_body)) + block_body.source)
    end

    # @return [Integer]
    def column_of(node)
      start = node.source_range.first
      newline_before = node.full_source.rindex("\n", start - 1)
      newline_before.nil? ? start : start - newline_before - 1
    end

    # @return [String]
    def dedent(source)
      lines = source.lines.map(&:rstrip)
      min_indent = lines.reject(&:empty?).map {|line| line[/^\s*/].length}.min || 0
      lines.map {|line| line[min_indent..] || line}.join("\n").strip
    end
  end
end
