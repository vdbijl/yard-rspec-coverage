class Widget < Machine
  include Spinning
  extend Countable

  attr_reader :size

  def self.build; end

  def wobble; end
  alias shake wobble
end
