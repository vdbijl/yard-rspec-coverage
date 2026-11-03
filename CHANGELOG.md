# Changelog

## Unreleased

Changed (these can change the coverage result of a project):

- `yard:rspec_coverage` parses only `YardRspec::Config.files`. The options in `.yardopts`, such
  as `--exclude`, still apply, but the files listed there are no longer added.
- Classes, modules and methods that spec files define outside describe blocks, such as helpers
  in `spec/support`, are left out of the documentation and of `yard stats`.
- Files ending in `_helper.rb` outside a spec directory, such as Rails view helpers, count for
  RSpec coverage again. Spec files are the files in a `spec/` directory and files ending in
  `_spec.rb`.
- An example without a block (`it 'spins twice'`) is pending, as in RSpec: it is labelled
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
