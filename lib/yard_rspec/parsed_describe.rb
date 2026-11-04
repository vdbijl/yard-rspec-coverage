# frozen_string_literal: true

module YardRspec
  # What DescribeHandler takes from a describe block's syntax tree: the class name and, per
  # described method, its examples. It keeps no syntax tree, so a describe that waits for the end
  # of a file list parse does not keep its spec file's tree alive (about 0.25 MB per spec file).
  class ParsedDescribe
    # @rbs @namespace: YARD::CodeObjects::NamespaceObject
    # @rbs @class_name: String
    # @rbs @entries: Array[Entry]

    # One described method, with its examples. A plain class: inline RBS cannot type a Struct.
    class Entry
      # Nil if the describe string names no method, as in `describe '#'`.
      attr_reader :description #: MethodDescription?

      # See ExampleExtractor#extract.
      attr_reader :examples #: Array[example_node]

      # 'file:line' of the describe of the method.
      attr_reader :location #: String

      # @rbs description: MethodDescription?
      # @rbs examples: Array[example_node]
      # @rbs location: String
      # @rbs return: void
      def initialize(description, examples, location)
        @description = description
        @examples = examples
        @location = location
      end
    end

    # 'file:line' of the describe.
    attr_reader :location #: String

    # @rbs namespace: YARD::CodeObjects::NamespaceObject -- Where the describe is; the class name
    #   is resolved from there.
    # @rbs class_name: String -- As written, such as 'Widget' or 'Shop::Widget'.
    # @rbs location: String -- 'file:line' of the describe.
    # @rbs entries: Array[Entry]
    # @rbs return: void
    def initialize(namespace:, class_name:, location:, entries:)
      @namespace = namespace
      @class_name = class_name
      @location = location
      @entries = entries
    end

    # Attaches the examples to the described methods, or records describe problems. Call it once
    # the described classes are in the registry.
    # @rbs return: void
    def attach
      target = resolve_namespace or return
      @entries.each {|entry| attach_entry(target, entry)}
    end

    private

    # @rbs return: YARD::CodeObjects::NamespaceObject? -- Nil for an unknown class, recorded as a
    #   problem unless it is loaded at runtime (a class of another gem is no typo), and for a
    #   constant such as `Widget = Class.new`, whose methods YARD does not know.
    def resolve_namespace
      resolved = YARD::Registry.resolve(@namespace, @class_name, true)
      if resolved.nil? && !loaded_constant?
        DescribeProblems.add("#{@location}: could not resolve class '#{@class_name}'")
      end
      resolved if resolved.is_a?(YARD::CodeObjects::NamespaceObject)
    end

    # @rbs return: bool
    def loaded_constant?
      Object.const_defined?(@class_name)
    rescue NameError
      false
    end

    # A missing method is a describe problem, unless the description is imprecise.
    # @rbs target: YARD::CodeObjects::NamespaceObject
    # @rbs entry: Entry
    # @rbs return: void
    def attach_entry(target, entry)
      description = entry.description
      if description.nil?
        DescribeProblems.add("#{entry.location}: could not parse the method name of the describe")
      elsif (method_obj = description.find_in(target))
        (method_obj[:rspec_examples] ||= []).concat(entry.examples)
      elsif !description.imprecise?
        DescribeProblems.add("#{entry.location}: could not find method '#{description}' "\
                             "on '#{@class_name}'")
      end
    end
  end
end
