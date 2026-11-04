# frozen_string_literal: true

module YardRspec
  # Attaches the examples of RSpec describe blocks to the described methods, as :rspec_examples.
  # When parsing a file list, the examples are attached after all files: YARD postpones files with
  # unknown namespaces, so a spec may be parsed before its class. The syntax tree is read right
  # away, so that a waiting describe (a ParsedDescribe) does not keep it alive.
  class DescribeHandler < YARD::Handlers::Ruby::Base
    include AstHelpers

    handles method_call(:describe)
    handles method_call(:context)
    namespace_only

    # @return [Regexp] A class name such as 'Widget' or 'Shop::Widget', not a topic such as
    #   'Spinning semantics'.
    CLASS_NAME = /\A[A-Z][A-Za-z0-9_:]*\z/

    # Deferred while parsing a file list, see the callbacks at the end of this file. There a
    # failure is recorded as a describe problem, so it does not abort the parse.
    def process
      deferred = globals.yard_rspec_deferred_describes
      return parse_describe&.attach if deferred.nil?

      DescribeProblems.recording_failure(location_of) do
        parsed = parse_describe
        deferred << parsed if parsed
      end
    end

    private

    # Method-only describes (describe '#eql?') are handled by their outer describe.
    # @return [ParsedDescribe, nil] Nil for a describe without a class name.
    def parse_describe
      class_name = described_name
      return nil if class_name.nil? || !class_name.match?(CLASS_NAME)

      description = extract_method_description
      entries = if description
                  [entry(description, block_body_of(statement), statement.line)]
                else
                  nested_entries
                end
      ParsedDescribe.new(namespace: namespace, class_name: class_name, location: location_of,
                         entries: entries)
    end

    # @return [String, nil] The first describe parameter; nil for `describe do`.
    def described_name
      first_parameter = statement.parameters.first
      Unquote.call(first_parameter.source) if ast_node?(first_parameter)
    end

    # @return [MethodDescription, nil] From the second describe parameter.
    def extract_method_description
      second_param = statement.parameters[1]
      return nil if !ast_node?(second_param)

      MethodDescription.parse(Unquote.call(second_param.source))
    end

    # @return [<ParsedDescribe::Entry>] The nested '#method' describes.
    def nested_entries
      block_body = block_body_of(statement)
      return [] if block_body.nil?

      NestedMethodDescribes.new(block_body).map do |description, nested_block_body, line|
        entry(description, nested_block_body, line)
      end
    end

    # @param [MethodDescription, nil] description
    # @param [YARD::Parser::Ruby::AstNode, nil] block_body
    # @return [ParsedDescribe::Entry]
    def entry(description, block_body, line)
      examples = description ? ExampleExtractor.new(block_body).extract : []
      ParsedDescribe::Entry.new(description, examples, location_of(line))
    end

    # @return [String] 'file:line', by default the line of the statement.
    def location_of(line = statement.line)
      "#{statement.file}:#{line}"
    end
  end
end

YARD::Parser::SourceParser.before_parse_list do |_files, global_state|
  global_state.yard_rspec_deferred_describes = []
  nil # Returning false would cancel the parse.
end

# Spec objects are removed only after the examples have been attached.
YARD::Parser::SourceParser.after_parse_list do |_files, global_state|
  global_state.yard_rspec_deferred_describes.each do |parsed_describe|
    YardRspec::DescribeProblems.recording_failure(parsed_describe.location) {parsed_describe.attach}
  end
  YardRspec::SpecObjects.remove
end
