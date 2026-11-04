# frozen_string_literal: true

# The library is annotated inline; sig/ holds the types of YARD, which ships none. The templates
# define top-level methods, which inline RBS cannot express, and stats.rb extends a YARD class
# inside class_eval; both keep their YARD tags.
target :lib do
  # Strict: also reports undeclared instance variables and expressions that fall back to untyped.
  configure_code_diagnostics(Steep::Diagnostic::Ruby.all_error)
  check 'lib', inline: true
  ignore 'lib/yard_rspec/stats.rb', inline: true
  signature 'sig'
  library 'pathname'
end
