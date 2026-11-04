# frozen_string_literal: true

# Shows the examples before the source.
def init
  super
  sections.place(:rspec_specs).before(:source, true)
end

# @return [String]
def rspec_specs
  erb(:rspec_specs)
end

# @param [<YardRspec::Example, YardRspec::ExampleGroup>] nodes See `method[:rspec_examples]`.
# @return [String] HTML list items.
def rspec_nodes_html(nodes)
  nodes.map do |node|
    node.is_a?(YardRspec::ExampleGroup) ? rspec_group_html(node) : rspec_example_html(node)
  end.join
end

# @param [YardRspec::Example] example
# @return [String]
def rspec_example_html(example)
  pending = example.pending? ? ' <span class="rspec_label rspec_pending">pending</span>' : ''
  "<li><details><summary>#{h(example.description)}#{pending}</summary>"\
    "<pre class=\"example code\">#{html_syntax_highlight(example.code, :ruby)}</pre>"\
    '</details></li>'
end

# @param [YardRspec::ExampleGroup] group
# @return [String]
def rspec_group_html(group)
  '<li class="rspec_context">'\
    "<span class=\"rspec_context_name\">#{h(group.description)}</span>"\
    "<ul class=\"rspec\">#{rspec_nodes_html(group.children)}</ul></li>"
end
