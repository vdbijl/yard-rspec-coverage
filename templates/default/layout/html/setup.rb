# frozen_string_literal: true

# @return [<String>]
def stylesheets
  super + %w[css/rspec.css]
end

# @return [<String>]
def javascripts
  super + %w[js/rspec.js]
end
