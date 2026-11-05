# frozen_string_literal: true

require 'pathname'

# Checks that the YARD stubs in sig/ describe YARD as it is installed: every class, module and
# method that they declare must exist. Steep trusts the stubs, and RBS::Test checks only the methods
# that the specs call, so a stub for a method that YARD renamed or never had stays unnoticed. Not
# part of the gem.
#
#   bundle exec rake prerelease:stubs
module RbsStubAudit
  # The namespace of the library that the stubs describe.
  LIBRARY = 'YARD'

  # The RBS libraries that sig/ uses, as in `library` in the Steepfile. With ALLOWED, the only
  # constants that differ between the gems that share this script.
  LIBRARIES = [].freeze

  # Stubbed methods that YARD does have, but not where Ruby can find them, with the reason.
  ALLOWED = {
    '::YARD::CodeObjects::ExtendedMethodObject#name' => 'Delegated to its MethodObject.',
    '::YARD::Parser::Ruby::AstNode#method_name' => 'Only on call nodes, a subclass of AstNode.',
    '::YARD::Parser::Ruby::AstNode#parameters' => 'Only on call nodes, a subclass of AstNode.',
    '::YARD::Parser::Ruby::AstNode#block' => 'Only on call nodes, a subclass of AstNode.'
  }.freeze

  # @return [<String>] The classes, modules and methods in the stubs that YARD does not have, such
  #   as '::YARD::Registry.resolve'. Without the ALLOWED ones.
  def self.problems
    require 'rbs'
    require 'yard'
    YARD::Handlers::Ruby.const_get(:Base) # Loads the classes that YARD defines next to it.
    environment = stub_environment
    builder = RBS::DefinitionBuilder.new(env: environment)
    names = environment.class_decls.keys.select {|name| name.to_s.start_with?("::#{LIBRARY}")}
    names.flat_map {|name| problems_of(name, builder)}.reject {|problem| ALLOWED.key?(problem)}
  end

  # @return [RBS::Environment] With the signatures in sig/.
  def self.stub_environment
    loader = RBS::EnvironmentLoader.new
    loader.add(path: Pathname('sig'))
    LIBRARIES.each {|library| loader.add(library:)}
    RBS::Environment.from_loader(loader).resolve_type_names
  end
  private_class_method :stub_environment

  def self.problems_of(name, builder)
    klass = Object.const_get(name.to_s)
    methods_of(klass, name, :instance, builder.build_instance(name)) +
      methods_of(klass, name, :singleton, builder.build_singleton(name))
  rescue NameError
    ["#{name} does not exist"]
  end
  private_class_method :problems_of

  # The methods that the stub of the class declares itself, which the class does not have.
  def self.methods_of(klass, name, kind, definition)
    definition.methods.filter_map do |method_name, method|
      next if method.defined_in != name || exists?(klass, method_name, kind)

      "#{name}#{kind == :instance ? '#' : '.'}#{method_name}"
    end
  end
  private_class_method :methods_of

  def self.exists?(klass, method_name, kind)
    if kind == :instance
      klass.method_defined?(method_name) || klass.private_method_defined?(method_name)
    else
      klass.respond_to?(method_name, true)
    end
  end
  private_class_method :exists?
end
