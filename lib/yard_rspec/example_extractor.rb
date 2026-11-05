# frozen_string_literal: true

module YardRspec
  # Extracts the RSpec examples of a describe block as a tree of example and context nodes.
  # Excluded examples (xit/xspecify/xexample) are pending.
  class ExampleExtractor
    # @rbs @block_node: YARD::Parser::Ruby::AstNode

    include AstHelpers

    # The keywords of examples that RSpec excludes from the run.
    PENDING_KEYWORDS = %i[xit xspecify xexample].freeze #: Array[Symbol]

    # The keywords of all examples, including the pending ones.
    KEYWORDS = (%i[it specify example] + PENDING_KEYWORDS).freeze #: Array[Symbol]

    # @rbs block_node: YARD::Parser::Ruby::AstNode -- The body of a describe block.
    # @rbs return: void
    def initialize(block_node)
      @block_node = block_node
    end

    # @rbs return: Array[example_node] -- The example and context nodes.
    def extract
      examples = [] #: Array[example_node]
      traverse(@block_node, examples)
      examples
    end

    private

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs nodes: Array[example_node]
    # @rbs return: void
    def traverse(node, nodes)
      if example_call?(node)
        nodes << build_example(node)
      elsif context_call?(node)
        add_context(node, nodes)
      else
        node.children.each {|child| traverse(child, nodes)}
      end
    end

    # A context without examples, such as one without a block, is left out.
    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs nodes: Array[example_node]
    # @rbs return: void
    def add_context(node, nodes)
      children = [] #: Array[example_node]
      traverse(block_body_of(node), children)
      return if children.empty?

      description = string_text(node.parameters(false).first)
      nodes << ExampleGroup.new(description: description, children: children)
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: bool -- Includes the `x` variants.
    def example_call?(node)
      node.type == :command && KEYWORDS.include?(node.method_name(true))
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: bool
    def context_call?(node)
      node.type == :command && describe_or_context_call?(node)
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: Example -- Pending for the `x` variants and examples without a block, which
    #   RSpec reports as pending.
    def build_example(node)
      description = string_text(node.parameters(false).first)
      Example.new(description: description.empty? ? 'example' : description,
                  code: extract_code(block_body_of(node)), pending: pending_example?(node))
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: bool
    def pending_example?(node)
      PENDING_KEYWORDS.include?(node.method_name(true)) || node.block.nil?
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: String -- The text as written, so with interpolations such as `#{count}`; empty
    #   if not a string literal, such as `format('runs %s', count)`. Adjacent literals
    #   (`'runs ' \ 'twice'`) are joined, as RSpec sees them.
    def string_text(node)
      case node.type
      when :string_literal
        # A string literal always has string content.
        content = node.children.find {|child| child.type == :string_content} #: YARD::Parser::Ruby::AstNode
        content.children.map(&:source).join
      when :string_concat
        node.children.map {|child| string_text(child)}.join
      else
        ''
      end
    end

    # @rbs block_body: YARD::Parser::Ruby::AstNode
    # @rbs return: String -- Empty without statements.
    def extract_code(block_body)
      return '' if block_body.empty?

      # The source starts at the first token; restore its indentation before dedenting.
      dedent((' ' * column_of(block_body)) + block_body.source)
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: Integer
    def column_of(node)
      start = node.source_range.first
      newline_before = node.full_source.rindex("\n", start - 1)
      newline_before.nil? ? start : start - newline_before - 1
    end

    # @rbs source: String
    # @rbs return: String
    def dedent(source)
      lines = source.lines.map(&:rstrip)
      min_indent = lines.reject(&:empty?).map {|line| line.length - line.lstrip.length}.min || 0
      lines.map {|line| line[min_indent..] || line}.join("\n").strip
    end
  end
end
