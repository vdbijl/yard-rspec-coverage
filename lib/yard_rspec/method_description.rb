# frozen_string_literal: true

module YardRspec
  # The method named by a describe string such as '#run', '.build' or '#initialize via Factory'.
  class MethodDescription
    # @rbs @imprecise: bool

    # '#' (instance) or '.' (class), followed by the method name.
    PATTERN = /\A([#.])(\S+)/ #: Regexp

    attr_reader :name #: String

    attr_reader :scope #: :instance | :class

    # @rbs text: String -- The describe string, without quotes.
    # @rbs return: MethodDescription? -- Nil if the text names no method.
    def self.parse(text)
      match = text.match(PATTERN)
      return nil if match.nil?

      new(name: match[2], scope: match[1] == '#' ? :instance : :class,
          imprecise: text.length > match[0].length)
    end

    # @rbs name: String
    # @rbs scope: :instance | :class
    # @rbs imprecise: bool
    # @rbs return: void
    def initialize(name:, scope:, imprecise:)
      @name = name
      @scope = scope
      @imprecise = imprecise
    end

    # @rbs return: bool -- Whether text follows the method name, as in '#initialize via
    #   SomeFactory'. A missing method is then not reported.
    def imprecise?
      @imprecise
    end

    # @rbs return: String -- '#name' or '.name'.
    def to_s
      "#{@scope == :instance ? '#' : '.'}#{name}"
    end

    # @rbs namespace: YARD::CodeObjects::NamespaceObject
    # @rbs return: YARD::CodeObjects::MethodObject? -- Searched in superclasses and mixins too.
    #   Falls back to the other scope, since specs sometimes write '#' for class methods, and from
    #   'new' to #initialize, which YARD documents for the constructor.
    def find_in(namespace)
      find_with_scope(namespace, @scope, name) || find_with_scope(namespace, other_scope, name) ||
        (find_with_scope(namespace, :instance, 'initialize') if name == 'new')
    end

    private

    # Includes superclasses and mixins, so examples end up on the module's method. Own methods
    # come first, found directly: the full list takes time quadratic in the number of methods.
    # @rbs namespace: YARD::CodeObjects::NamespaceObject
    # @rbs scope: :instance | :class
    # @rbs method_name: String
    # @rbs return: YARD::CodeObjects::MethodObject?
    def find_with_scope(namespace, scope, method_name)
      namespace.child(name: method_name.to_sym, scope: scope, type: :method) ||
        namespace.meths(scope: scope, visibility: %i[public protected private], included: true)
                 .find {|method| method.name.to_s == method_name}
    end

    # @rbs return: :instance | :class
    def other_scope
      @scope == :instance ? :class : :instance
    end
  end
end
