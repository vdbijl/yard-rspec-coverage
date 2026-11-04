# frozen_string_literal: true

module YardRspec
  # The classes, modules and methods that spec files define outside describe blocks, such as
  # helpers in spec/support. YARD parses the spec files for their examples, but their own code is
  # no part of the documentation, nor of `yard stats`.
  module SpecObjects
    # Removes objects defined only in spec files, and the spec files from the files of the others,
    # such as a class that a spec reopens.
    # @rbs return: void
    def self.remove
      YARD::Registry.all.each do |object|
        own_files = object.files.reject {|file, _line| Coverage.spec_file?(file)}
        next if own_files == object.files

        own_files.empty? ? delete(object) : object.files.replace(own_files)
      end
    end

    # A namespace from another gem (`class Rack::Static::Middleware`) is a proxy without children.
    # @rbs object: YARD::CodeObjects::Base
    # @rbs return: void
    def self.delete(object)
      namespace = object.namespace
      namespace.children.delete(object) if !namespace.is_a?(YARD::CodeObjects::Proxy)
      YARD::Registry.delete(object)
    end
    private_class_method :delete
  end
end
