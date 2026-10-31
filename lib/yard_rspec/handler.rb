# frozen_string_literal: true

module YardRspec
  # Attaches the examples of RSpec describe blocks to the described methods, as :rspec_examples.
  # When parsing a file list, describes are processed after all files: YARD postpones files with
  # unknown namespaces, so a spec may be parsed before its class.
  class DescribeHandler < YARD::Handlers::Ruby::Base
    handles method_call(:describe)
    handles method_call(:context)
    namespace_only

    # Deferred while parsing a file list, see the callbacks at the end of this file.
    def process
      @describe_namespace = namespace
      if globals.yard_rspec_deferred_describes
        globals.yard_rspec_deferred_describes << -> {process_describe}
      else
        process_describe
      end
    end

    private

    def process_describe
      obj_name = unquote(statement.parameters.first.source)

      # Method-only describes (describe '#eql?') are handled by their outer describe.
      target_namespace = resolve_namespace(obj_name)
      return if target_namespace.nil?

      description = extract_method_description
      if description
        document_method(target_namespace, obj_name, description, statement.last&.last,
                        location_of)
      else
        process_nested_describes(target_namespace, obj_name)
      end
    end

    # @return [MethodDescription, nil] From the second describe parameter.
    def extract_method_description
      second_param = statement.parameters[1]
      return nil if !ast_node?(second_param)

      MethodDescription.parse(unquote(second_param.source))
    end

    # Records a describe problem for an unknown class, unless it is loaded at runtime: a class
    # from another gem (e.g. YARD::CLI::Stats) is not a typo.
    # @return [YARD::CodeObjects::Base, nil]
    def resolve_namespace(obj_name)
      # Not a constant, e.g. describe 'Partial Order Reduction semantics'.
      return nil if !obj_name.match?(/\A[A-Z][A-Za-z0-9_:]*\z/)

      return @describe_namespace if obj_name == @describe_namespace.name.to_s

      resolved = YARD::Registry.resolve(@describe_namespace, obj_name, true)
      if resolved.nil? && !loaded_constant?(obj_name)
        DescribeProblems.add("#{location_of}: could not resolve class '#{obj_name}'")
      end
      resolved
    end

    # @return [Boolean]
    def loaded_constant?(obj_name)
      Object.const_defined?(obj_name)
    rescue NameError
      false
    end

    # A missing method is a describe problem, unless the description is imprecise.
    def document_method(target_namespace, obj_name, description, block_body, location)
      method_obj = description.find_in(target_namespace)
      if method_obj
        attach_examples_to(method_obj, block_body)
      elsif !description.imprecise?
        add_missing_method_problem(description, obj_name, location)
      end
    end

    def add_missing_method_problem(description, obj_name, location)
      DescribeProblems.add("#{location}: could not find method '#{description}' " \
                           "on '#{obj_name}'")
    end

    def attach_examples_to(method_obj, block_body)
      examples = ExampleExtractor.new(block_body).extract
      method_obj[:rspec_examples] ||= []
      method_obj[:rspec_examples].concat(examples)
    end

    def process_nested_describes(target_namespace, obj_name)
      block_body = statement.last&.last
      return if block_body.nil?

      each_method_describe(block_body) do |description, nested_block_body, node_line|
        document_method(target_namespace, obj_name, description, nested_block_body,
                        location_of(node_line))
      end
    end

    # Yields the description, block body and line of each nested method describe.
    def each_method_describe(node, &)
      return if !ast_node?(node)

      if method_describe_node?(node)
        description = MethodDescription.parse(unquote(node.parameters.first.source))
        yield(description, node.last&.last, node.line)
      else
        node.children.each {|child| each_method_describe(child, &)}
      end
    end

    # @return [Boolean]
    def method_describe_node?(node)
      return false if node.type != :command

      name_node = node.children[0]
      return false if !describe_or_context_call?(name_node)

      first_param = node.parameters.first
      return false if !ast_node?(first_param)

      unquote(first_param.source).start_with?('#', '.')
    rescue StandardError
      false
    end

    # @return [Boolean]
    def describe_or_context_call?(name_node)
      name_node&.type == :ident && %w[describe context].include?(name_node.source)
    end

    # @return [Boolean]
    def ast_node?(node)
      node.is_a?(YARD::Parser::Ruby::AstNode)
    end

    # @return [String]
    def unquote(source)
      source.gsub(/['"]/, '')
    end

    # @return [String] 'file:line', by default the line of the statement.
    def location_of(line = statement.line || '?')
      "#{statement.file || '(unknown)'}:#{line}"
    end
  end
end

YARD::Parser::SourceParser.before_parse_list do |_files, global_state|
  global_state.yard_rspec_deferred_describes = []
  nil # Returning false would cancel the parse.
end

YARD::Parser::SourceParser.after_parse_list do |_files, global_state|
  global_state.yard_rspec_deferred_describes.each(&:call)
end
