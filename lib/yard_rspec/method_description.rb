# frozen_string_literal: true

module YardRspec
  # The method named by a describe string such as '#run', '.build' or '#initialize via Factory'.
  class MethodDescription
    # @return [Regexp] '#' (instance) or '.' (class), followed by the method name.
    PATTERN = /^([#.])(\S+)/

    # @return [String]
    attr_reader :name

    # @return [:instance, :class]
    attr_reader :scope

    # @param [String] text The describe string, without quotes.
    # @return [MethodDescription, nil] Nil if the text names no method.
    def self.parse(text)
      match = text.match(PATTERN)
      return nil if match.nil?

      new(name: match[2], scope: match[1] == '#' ? :instance : :class,
          imprecise: text.length > match[0].length)
    end

    # @param [String] name
    # @param [:instance, :class] scope
    # @param [Boolean] imprecise
    def initialize(name:, scope:, imprecise:)
      @name = name
      @scope = scope
      @imprecise = imprecise
    end

    # Whether text follows the method name, as in '#initialize via SomeFactory'. A missing method
    # is then not reported.
    # @return [Boolean]
    def imprecise?
      @imprecise
    end

    # @return [String] '#name' or '.name'.
    def to_s
      "#{@scope == :instance ? '#' : '.'}#{name}"
    end

    # Falls back to the other scope, because specs sometimes write '#' for class methods.
    # @param [YARD::CodeObjects::NamespaceObject] namespace
    # @return [YARD::CodeObjects::MethodObject, nil] Also searched in superclasses and mixins.
    def find_in(namespace)
      find_with_scope(namespace, @scope) || find_with_scope(namespace, other_scope)
    end

    private

    # Includes mixins, so examples end up on the module's method. Own methods come first.
    def find_with_scope(namespace, scope)
      namespace
        .meths(scope: scope, visibility: %i[public protected private], included: true)
        .find {|method| method.name.to_s == name}
    end

    def other_scope
      @scope == :instance ? :class : :instance
    end
  end
end
