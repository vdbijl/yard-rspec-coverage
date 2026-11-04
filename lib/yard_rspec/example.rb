# frozen_string_literal: true

module YardRspec
  # An `it`, `specify` or `example` of a describe block, kept in `method[:rspec_examples]`.
  class Example
    # @rbs @pending: bool

    # The text after `it`, or 'example' if it is not a string literal.
    attr_reader :description #: String

    # The code of the block, without its common indentation.
    attr_reader :code #: String

    # @rbs description: String
    # @rbs code: String -- Empty without a block.
    # @rbs pending: bool -- Whether RSpec does not run it: `xit`, or an example without a block.
    # @rbs return: void
    def initialize(description:, code:, pending: false)
      @description = description
      @code = code
      @pending = pending
    end

    # @rbs return: bool
    def pending?
      @pending
    end

    # @rbs return: Array[Example] -- Itself, so that an example and an ExampleGroup are asked alike.
    def examples
      [self]
    end
  end
end
