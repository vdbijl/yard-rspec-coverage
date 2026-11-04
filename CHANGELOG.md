# Changelog

## Unreleased

Changed:

- `method[:rspec_examples]` holds `YardRspec::Example` and `YardRspec::ExampleGroup` objects
  instead of hashes. Both answer `examples`, the examples at any depth. YARD saves them with
  Marshal, so a `.yardoc` that holds them loads only when the plugin is loaded. A `.yardoc`
  written by 0.2.0 holds hashes: regenerate it.
- `YardRspec::Config.minimum_rspec_coverage=` and `files=` accept only a `Float` and an
  `Array` of `String`. Assigning `nil` no longer restores the default; assign
  `Config::DEFAULT_MINIMUM_RSPEC_COVERAGE` or `Config::DEFAULT_FILES`.
- The description of a context whose description is not a string literal is `''` instead of nil.
- `ExampleExtractor.new` and `NestedMethodDescribes.new` take a syntax tree, no longer nil: use
  `AstHelpers::EMPTY_BODY` for a describe without a block. `NestedMethodDescribes#each` needs a
  block and yields one array of the description, the block body and the line.
  `ParsedDescribe::Entry` is a plain class instead of a Struct.
- `DescribeProblems.add` returns nil, no longer the list of problems that the registry keeps.

Development:

- The code has inline RBS type annotations, checked by Steep with strict diagnostics (`rake steep`,
  part of `rake`). The types are documented by `yard-inline-rbs`, enabled in `.yardopts`. The
  `sig/` directory holds the types of YARD, and is not part of the gem.
- `Gemfile.lock` is no longer committed: a gem is tested against the newest versions that its
  gemspec allows.

## 0.2.0

Changed (these can change the coverage result of a project):

- `yard:rspec_coverage` parses only `YardRspec::Config.files`. The options in `.yardopts`, such
  as `--exclude`, still apply, but the files listed there are no longer added.
- Classes, modules and methods that spec files define outside describe blocks, such as helpers
  in `spec/support`, are left out of the documentation and of `yard stats`.
- Files ending in `_helper.rb` outside a spec directory, such as Rails view helpers, count for
  RSpec coverage again. Spec files are the files in a `spec/` directory and files ending in
  `_spec.rb`.
- An example without a block (`it 'spins twice'`) is pending, as in RSpec: it is labeled
  "pending" and does not count as coverage.
- A description that is not a string literal, such as `it format('runs %s', 1)`, is shown as
  `example`. A description with interpolation is shown as written.

Added:

- Descriptions split over several lines (`it 'spins ' \ 'twice'`) are joined, as in RSpec.
- `describe '.new'` and `describe '#new'` document `#initialize`, unless the class defines a
  class method `new` itself.

Fixed:

- An exact coverage percentage failed an equal minimum, for example 57 of 100 methods against a
  minimum of 57.
- A describe of a class defined as a constant (`Widget = Class.new`), a spec file that reopens a
  class of another gem, and describes or contexts without a block or without arguments no
  longer stop the processing of a describe.
- The plugin no longer keeps the syntax tree of every spec file in memory until the end of the
  parse. In a project with about 600 spec files, peak memory dropped from 247 MB to 72 MB.
- Looking up the described method is faster, especially in large projects.

## 0.1.3

First public release as `yard-rspec-coverage`.

- The RSpec examples in the documentation have a new look:
  - Example code is syntax-highlighted, like the method source.
  - The heading shows the number of examples, with an "expand all" link when there is more
    than one.
  - Pending examples (`xit`, `xspecify`, `xexample`) get a "pending" label.
  - Contexts are grouped with a line along their examples.
  - A public method without specs gets a red "no specs" label.
