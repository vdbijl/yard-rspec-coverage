# frozen_string_literal: true

module YardRspec
  # Removes the quotes around the source of a string literal.
  module Unquote
    # @param [String] source For example `"'#run'"`.
    # @return [String] Without the surrounding quotes only: `"it's"` stays `it's`.
    def self.call(source)
      source.sub(/\A(['"])(.*)\1\z/m, '\\2')
    end
  end
end
