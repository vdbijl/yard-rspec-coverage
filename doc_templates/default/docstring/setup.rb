# frozen_string_literal: true

# Only for this project's own documentation, via .yardopts. YARD shows a lone @return text as the
# summary too, so it appears twice; here the summary is the description only.
def docstring_text
  object.docstring.to_s.strip
end
