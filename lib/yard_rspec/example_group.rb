# frozen_string_literal: true

module YardRspec
  # The examples of a `context` or `describe` block inside a describe block, kept in
  # `method[:rspec_examples]` next to the examples that are not in a group.
  class ExampleGroup
    # The text after `context` or `describe`.
    attr_reader :description #: String

    # The examples and groups in the block, in order.
    attr_reader :children #: Array[example_node]

    # @rbs description: String -- Empty if the block has no string description.
    # @rbs children: Array[example_node]
    # @rbs return: void
    def initialize(description:, children:)
      @description = description
      @children = children
    end

    # @rbs return: Array[Example] -- The examples of the children, at any depth.
    def examples
      children.flat_map(&:examples)
    end
  end
end
