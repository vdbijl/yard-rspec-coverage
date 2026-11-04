# frozen_string_literal: true

require 'yard'
require_relative 'yard_rspec/ast_helpers'
require_relative 'yard_rspec/config'
require_relative 'yard_rspec/coverage'
require_relative 'yard_rspec/describe_problems'
require_relative 'yard_rspec/example'
require_relative 'yard_rspec/example_extractor'
require_relative 'yard_rspec/example_group'
require_relative 'yard_rspec/method_description'
require_relative 'yard_rspec/nested_method_describes'
require_relative 'yard_rspec/parsed_describe'
require_relative 'yard_rspec/handler'
require_relative 'yard_rspec/spec_objects'
require_relative 'yard_rspec/stats'
require_relative 'yard_rspec/unquote'

# __dir__ is nil only in eval, which Steep cannot know.
# steep:ignore:start
YARD::Templates::Engine.register_template_path File.expand_path('../templates', __dir__)
# steep:ignore:end
