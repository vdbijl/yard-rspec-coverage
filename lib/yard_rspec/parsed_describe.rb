# frozen_string_literal: true

module YardRspec
  # What DescribeHandler takes from a describe block's syntax tree: the class name and, per
  # described method, its examples. It keeps no syntax tree, so a describe that waits for the end
  # of a file list parse does not keep its spec file's tree alive (about 0.25 MB per spec file).
  class ParsedDescribe
    # One described method, with its examples.
    # @attr [MethodDescription, nil] description Nil if the describe string names no method, as in
    #   `describe '#'`.
    # @attr [<Hash>] examples See ExampleExtractor#extract.
    # @attr [String] location 'file:line' of the describe of the method.
    Entry = Struct.new(:description, :examples, :location)

    # @return [String] 'file:line' of the describe.
    attr_reader :location

    # @param [YARD::CodeObjects::NamespaceObject] namespace Where the describe is; the class name
    #   is resolved from there.
    # @param [String] class_name As written, such as 'Widget' or 'Shop::Widget'.
    # @param [String] location 'file:line' of the describe.
    # @param [<Entry>] entries
    def initialize(namespace:, class_name:, location:, entries:)
      @namespace = namespace
      @class_name = class_name
      @location = location
      @entries = entries
    end

    # Attaches the examples to the described methods, or records describe problems. Call it once
    # the described classes are in the registry.
    def attach
      target = resolve_namespace or return
      @entries.each {|entry| attach_entry(target, entry)}
    end

    private

    # @return [YARD::CodeObjects::NamespaceObject, nil] Nil for an unknown class, recorded as a
    #   problem unless it is loaded at runtime (a class of another gem is no typo), and for a
    #   constant such as `Widget = Class.new`, whose methods YARD does not know.
    def resolve_namespace
      resolved = YARD::Registry.resolve(@namespace, @class_name, true)
      if resolved.nil? && !loaded_constant?
        DescribeProblems.add("#{@location}: could not resolve class '#{@class_name}'")
      end
      resolved if resolved.is_a?(YARD::CodeObjects::NamespaceObject)
    end

    # @return [Boolean]
    def loaded_constant?
      Object.const_defined?(@class_name)
    rescue NameError
      false
    end

    # A missing method is a describe problem, unless the description is imprecise.
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
