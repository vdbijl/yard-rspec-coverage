# frozen_string_literal: true

require 'pathname'

# Converts the inline RBS annotations of lib/ to a .rbs file, for RBS::Test, which reads only .rbs
# files. Declares the methods of the gem's own classes and modules, with their signatures. Not part
# of the gem; see RbsRuntime.
module RbsFromInline
  # Writes the signatures of the inline annotations of lib/ to inline.rbs in the directory.
  # @param [String] directory
  # @param [String] namespace The top-level module of the gem, such as 'YardRspec'.
  # @param [<String>] libraries The RBS libraries that the signatures use, such as 'rbs'.
  def self.generate(directory, namespace, libraries)
    require 'rbs'
    require 'prism'
    environment = inline_environment(libraries)
    builder = RBS::DefinitionBuilder.new(env: environment)
    declarations = environment.class_decls.filter_map do |type_name, entry|
      declaration(builder, type_name, entry, namespace)
    end
    File.write(File.join(directory, 'inline.rbs'), signatures(declarations))
  end

  # @return [RBS::Environment] With the signatures in sig/ and the inline annotations of lib/.
  def self.inline_environment(libraries)
    loader = RBS::EnvironmentLoader.new
    loader.add(path: Pathname('sig'))
    libraries.each {|library| loader.add(library:)}
    environment = RBS::Environment.from_loader(loader)
    Dir['lib/**/*.rb'].each {|file| add_source(environment, file)}
    environment.resolve_type_names
  end
  private_class_method :inline_environment

  def self.add_source(environment, file)
    content = File.read(file)
    buffer = RBS::Buffer.new(name: file, content:)
    prism = Prism.parse(content, filepath: file)
    result = RBS::InlineParser.parse(buffer, prism)
    environment.add_source(RBS::Source::Ruby.new(buffer, prism, result.declarations,
                                                 result.diagnostics))
  end
  private_class_method :add_source

  # @return [RBS::AST::Declarations::Base, nil] A class or module of the gem with its methods; nil
  #   for the rest, which RBS::Test does not check.
  def self.declaration(builder, type_name, entry, namespace)
    return if !type_name.to_s.start_with?("::#{namespace}")

    members = methods_of(builder.build_instance(type_name), type_name, :instance) +
              methods_of(builder.build_singleton(type_name), type_name, :singleton)
    return if members.empty?

    if entry.is_a?(RBS::Environment::ModuleEntry)
      module_of(type_name, members)
    else
      class_of(type_name, members)
    end
  end
  private_class_method :declaration

  def self.module_of(type_name, members)
    RBS::AST::Declarations::Module.new(name: type_name.relative!, type_params: [], members:,
                                       self_types: [], annotations: [], location: nil,
                                       comment: nil)
  end
  private_class_method :module_of

  def self.class_of(type_name, members)
    RBS::AST::Declarations::Class.new(name: type_name.relative!, type_params: [], members:,
                                      super_class: nil, annotations: [], location: nil,
                                      comment: nil)
  end
  private_class_method :class_of

  # The methods that the class defines itself: the rest is checked where it is defined.
  def self.methods_of(definition, type_name, kind)
    definition.methods.filter_map do |name, method|
      method_definition(name, kind, method) if method.defined_in == type_name
    end
  end
  private_class_method :methods_of

  def self.method_definition(name, kind, method)
    overloads = method.defs.map do |overload|
      RBS::AST::Members::MethodDefinition::Overload.new(method_type: overload.type,
                                                        annotations: [])
    end
    RBS::AST::Members::MethodDefinition.new(
      name:, kind:, overloads:, annotations: [], location: nil, comment: nil, overloading: false,
      visibility: method.accessibility == :private ? :private : :public
    )
  end
  private_class_method :method_definition

  def self.signatures(declarations)
    io = StringIO.new
    RBS::Writer.new(out: io).write(declarations)
    io.string
  end
  private_class_method :signatures
end
