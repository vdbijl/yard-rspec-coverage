# frozen_string_literal: true

module YardRspec
  # Checks on YARD's Ruby AST that the handler, the example extractor and the nested describe
  # scanner share, so that they agree on which calls are describes.
  module AstHelpers
    private

    # @return [Boolean]
    def ast_node?(node)
      node.is_a?(YARD::Parser::Ruby::AstNode)
    end

    # @param [YARD::Parser::Ruby::MethodCallNode] call_node A command such as `describe Widget`.
    # @return [Boolean]
    def describe_or_context_call?(call_node)
      %i[describe context].include?(call_node.method_name(true))
    end

    # @param [YARD::Parser::Ruby::MethodCallNode] call_node A command such as `it 'spins' do end`.
    # @return [YARD::Parser::Ruby::AstNode, nil] The statements in the block, nil without a block.
    def block_body_of(call_node)
      call_node.block&.last
    end
  end
end
