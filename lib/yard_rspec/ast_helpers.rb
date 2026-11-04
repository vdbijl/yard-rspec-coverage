# frozen_string_literal: true

module YardRspec
  # Checks on YARD's Ruby AST that the handler, the example extractor and the nested describe
  # scanner share, so that they agree on which calls are describes.
  module AstHelpers
    # The body of a block that is not there, so that callers need no nil check. It has no
    # statements, as has the body of an empty block.
    EMPTY_BODY = YARD::Parser::Ruby::AstNode.new(:list, []) #: YARD::Parser::Ruby::AstNode

    private

    # @rbs node: YARD::Parser::Ruby::AstNode?
    # @rbs return: bool
    def ast_node?(node)
      node.is_a?(YARD::Parser::Ruby::AstNode)
    end

    # @rbs call_node: YARD::Parser::Ruby::MethodCallNode -- A command such as `describe Widget`.
    # @rbs return: bool
    def describe_or_context_call?(call_node)
      %i[describe context].include?(call_node.method_name(true))
    end

    # @rbs call_node: YARD::Parser::Ruby::MethodCallNode -- A command such as
    #   `it 'spins' do end`.
    # @rbs return: YARD::Parser::Ruby::AstNode -- The statements in the block, EMPTY_BODY without a
    #   block.
    def block_body_of(call_node)
      call_node.block&.last || EMPTY_BODY
    end
  end
end
