# frozen_string_literal: true

module YardRspec
  # The `describe '#method'` and `describe '.method'` blocks nested in a describe block.
  class NestedMethodDescribes
    # @rbs @block_body: YARD::Parser::Ruby::AstNode

    include Enumerable #[[MethodDescription?, YARD::Parser::Ruby::AstNode, Integer]]
    include AstHelpers

    # @rbs block_body: YARD::Parser::Ruby::AstNode -- The body of the outer describe block.
    # @rbs return: void
    def initialize(block_body)
      @block_body = block_body
    end

    # @yield Called for each method describe with an array of the description (nil if the string
    #   names no method, as in `describe '#'`), the body of the nested block (empty without a
    #   block) and the line.
    # @rbs &block: ([MethodDescription?, YARD::Parser::Ruby::AstNode, Integer]) -> void
    # @rbs return: void
    def each(&)
      walk(@block_body, &)
    end

    private

    # Does not look inside a method describe.
    # @rbs node: YARD::Parser::Ruby::AstNode
    # @yield Called for each method describe, as in #each.
    # @rbs &block: ([MethodDescription?, YARD::Parser::Ruby::AstNode, Integer]) -> void
    # @rbs return: void
    def walk(node, &)
      if method_describe_node?(node)
        description = MethodDescription.parse(source_of(node.parameters.first))
        yield [description, block_body_of(node), node.line]
      else
        node.children.each {|child| walk(child, &)}
      end
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: bool
    def method_describe_node?(node)
      node.type == :command && describe_or_context_call?(node) &&
        source_of(node.parameters.first).start_with?('#', '.')
    end

    # @rbs node: YARD::Parser::Ruby::AstNode
    # @rbs return: String -- Without quotes.
    def source_of(node)
      Unquote.call(node.source)
    end
  end
end
