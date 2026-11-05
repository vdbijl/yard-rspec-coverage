# frozen_string_literal: true

require 'tmpdir'
require_relative 'rbs_from_inline'

# Runs the specs with the runtime type checker of RBS on the classes of the gem, which checks the
# inline signatures against the arguments and return values that the specs produce. Steep checks
# the code against the signatures; this checks the signatures, and the stubs in sig/, against the
# real YARD. RBS::Test reads .rbs files, so RbsFromInline converts the annotations first.
# Not part of the gem.
#
#   bundle exec rake spec:coverage
module RbsRuntime
  # The top-level module of the gem. With LIBRARIES, the only constants that differ between the
  # gems that share this script.
  NAMESPACE = 'YardRspec'

  # The RBS libraries that the signatures of the gem use, as in `library` in the Steepfile.
  LIBRARIES = [].freeze

  # @return [String] The classes to check.
  TARGET = "#{NAMESPACE}::*".freeze

  # Runs the block with the checker on for the processes that it starts, such as RSpec.
  def self.with_checker
    Dir.mktmpdir('rbs_runtime') do |directory|
      RbsFromInline.generate(directory, NAMESPACE, LIBRARIES)
      saved_environment = ENV.to_h
      ENV.update(environment(directory))
      yield
    ensure
      ENV.replace(saved_environment) if saved_environment
    end
  end

  # @return [{String => String}] The environment of the specs. Double suite rspec: an RSpec double
  #   is accepted where a YARD object is expected. Sample size ALL: RBS::Test checks every element
  #   of an array or hash, not a sample.
  def self.environment(directory)
    {
      'RBS_TEST_TARGET' => TARGET,
      'RBS_TEST_OPT' => ["-I #{directory}", "-I #{File.expand_path('sig')}",
                         *LIBRARIES.map {|library| "-r #{library}"}].join(' '),
      'RBS_TEST_DOUBLE_SUITE' => 'rspec',
      'RBS_TEST_SAMPLE_SIZE' => 'ALL',
      'RBS_TEST_RAISE' => 'true',
      'RBS_TEST_LOGLEVEL' => 'error',
      'RUBYOPT' => [ENV.fetch('RUBYOPT', nil), '-rrbs/test/setup'].compact.join(' ')
    }
  end
  private_class_method :environment
end
