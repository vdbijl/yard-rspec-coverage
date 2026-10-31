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

# @param [<Hash>] nodes Example and context nodes, see `method[:rspec_examples]`.
# @return [String] HTML list items.
def rspec_nodes_html(nodes)
  nodes.map {|node| node[:children] ? rspec_group_html(node) : rspec_example_html(node)}.join
end

# @param [{description: String, code: String, pending: Boolean}] example
# @return [String]
def rspec_example_html(example)
  pending = example[:pending] ? ' <span class="rspec_label rspec_pending">pending</span>' : ''
  "<li><details><summary>#{h(example[:description])}#{pending}</summary>" \
    "<pre class=\"example code\">#{html_syntax_highlight(example[:code], :ruby)}</pre>" \
    '</details></li>'
end

# @param [{description: String, children: [<Hash>]}] group
# @return [String]
def rspec_group_html(group)
  '<li class="rspec_context">' \
    "<span class=\"rspec_context_name\">#{h(group[:description])}</span>" \
    "<ul class=\"rspec\">#{rspec_nodes_html(group[:children])}</ul></li>"
end
