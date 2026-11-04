# frozen_string_literal: true

require 'json'
require 'rspec/core/formatters/base_formatter'

module YardRspecCompare
  # An RSpec formatter that writes every example RSpec loads to the JSON file in
  # ENV['EXAMPLE_LIST_OUT']. Loaded into the RSpec process of the compared project with
  # `--require`, so it must not depend on the plugin. Meant for `rspec --dry-run`.
  class ExampleLister < RSpec::Core::Formatters::BaseFormatter
    RSpec::Core::Formatters.register self, :stop

    # @param [RSpec::Core::Notifications::ExamplesNotification] notification
    def stop(notification)
      examples = notification.examples.map {|example| example_hash(example)}
      File.write(ENV.fetch('EXAMPLE_LIST_OUT'), JSON.pretty_generate(examples))
    end

    private

    def example_hash(example)
      metadata = example.metadata
      { file: File.expand_path(metadata[:file_path]), line: metadata[:line_number],
        description: example.description, groups: group_arguments(example),
        pending: !metadata[:skip].nil? || metadata[:block].nil?,
        shared_group: metadata[:shared_group_inclusion_backtrace]&.any? || false }
    end

    # @return [<<String>>] The arguments of each group, outermost first.
    def group_arguments(example)
      example.example_group.parent_groups.reverse.map do |group|
        group.metadata[:description_args].map(&:to_s)
      end
    end
  end
end
