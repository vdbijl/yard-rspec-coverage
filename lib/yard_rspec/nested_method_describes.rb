# frozen_string_literal: true

module YardRspec
  # The `describe '#method'` and `describe '.method'` blocks nested in a describe block.
  class NestedMethodDescribes
    include Enumerable
    include AstHelpers

    # @param [YARD::Parser::Ruby::AstNode] block_body The body of the outer describe block.
    def initialize(block_body)
      @block_body = block_body
    end

    # @yieldparam [MethodDescription, nil] description Nil if the string names no method, as in
    #   `describe '#'`.
    # @yieldparam [YARD::Parser::Ruby::AstNode, nil] block_body The body of the nested block, nil
    #   without a block.
    # @yieldparam [Integer] line
    def each(&)
      return enum_for(:each) if !block_given?

      walk(@block_body, &)
    end

    private

    # Does not look inside a method describe.
    def walk(node, &)
      if method_describe_node?(node)
        description = MethodDescription.parse(source_of(node.parameters.first))
        yield(description, block_body_of(node), node.line)
      else
        node.children.each {|child| walk(child, &)}
      end
    end

    # @return [Boolean]
    def method_describe_node?(node)
      node.type == :command && describe_or_context_call?(node) &&
        source_of(node.parameters.first).start_with?('#', '.')
    end

    # @return [String] Without quotes.
    def source_of(node)
      Unquote.call(node.source)
    end
  end
end
