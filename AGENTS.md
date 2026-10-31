# yard-rspec-coverage plugin — agent briefing

## What this is

A YARD plugin that embeds RSpec examples inside YARD HTML documentation. Its
`yard:rspec_coverage` Rake task reports public methods without specs and describe blocks that
match no class or method, and it adds an RSpec coverage row to `yard stats` output.

## File layout

```
lib/
  yard-rspec-coverage.rb      # Entry point: requires handler + stats, registers template path
  yard_rspec/
    handler.rb                # YARD handler — parses describe/context blocks, attaches examples
    example_extractor.rb      # Extracts it/specify/example examples (as a context tree) from an AST block
    method_description.rb     # YardRspec::MethodDescription: '#run'/'.build' describe strings, method lookup
    config.rb                 # YardRspec::Config: minimum_rspec_coverage (default 100.0), files
    coverage.rb               # YardRspec::Coverage.countable_methods: which methods need specs
    describe_problems.rb      # YardRspec::DescribeProblems: describes matching no class/method
    rake_tasks.rb             # `require 'yard_rspec/rake_tasks'` entry point; loads the tasks
    stats.rb                  # Extends YARD::CLI::Stats with stats_for_rspec
  tasks/
    yard_rspec.rake           # yard:doc and yard:rspec_coverage (coverage gate) tasks

templates/default/
  method_details/html/
    setup.rb                  # Hooks :rspec_specs section into YARD's rendering pipeline
    rspec_specs.erb           # Renders the examples tree, or a "no specs" label if a counted method has none
  layout/html/setup.rb        # Adds rspec.css and rspec.js to every page
  fulldoc/html/css/rspec.css  # Styles of the examples section
  fulldoc/html/js/rspec.js    # The "expand all" link

spec/
  spec_helper.rb
  yard_rspec/
    describe_handler_spec.rb  # Handler + HTML template tests
    example_extractor_spec.rb # ExampleExtractor tests
    method_description_spec.rb # YardRspec::MethodDescription tests
    config_spec.rb            # YardRspec::Config tests
    rake_tasks_spec.rb        # Rake task entry point tests
    coverage_spec.rb          # YardRspec::Coverage tests
    describe_problems_spec.rb # YardRspec::DescribeProblems tests
    stats_spec.rb             # stats_for_rspec tests
```

## How the plugin works end-to-end

1. **Parsing phase** (`yard doc` or `yard stats`): YARD parses all Ruby files, including
   spec files. `DescribeHandler` fires on every `describe`/`context` call. When YARD parses a
   file list (`YARD.parse`, `yard doc`, `yard stats`) it defers the work until all files are
   parsed (closures in the parser `globals`, run by an `after_parse_list` callback), because
   YARD postpones files with unknown namespaces and a spec may be parsed before its class.
   With `YARD.parse_string` there is no file list, so it processes immediately. It then:
   - Resolves the class name from the first parameter
   - Parses the second parameter into a `MethodDescription`: method name and scope
     (`:instance` for `#`, `:class` for `.`)
   - Looks the method up in the class, its superclasses, and its included (`#`) or extended
     (`.`) modules; a mixin method gets the examples on the module's own method object
   - Falls back to the other scope if not found (cross-scope fallback — specs sometimes
     write `#` for class methods)
   - Calls `ExampleExtractor` on the block body to collect `it`/`specify`/`example` examples
   - Stores a tree on `method_obj[:rspec_examples]`: each node is either an example
     `{description:, code:}` (plus `pending: true` for `xit`/`xspecify`/`xexample`) or a context group `{description:, children: [...]}`
   - Records a describe problem when a described class or method cannot be found (see
     describe problems below)

   Nested forms are also supported:
   - `RSpec.describe ClassName do; describe '#method' do; ... end; end`
   - `describe ClassName do; context '...' do; describe '#method' do; ... end; end; end`

2. **Rendering phase** (`yard doc`): `setup.rb` inserts `:rspec_specs` before `:source` in
   YARD's section list. For each method:
   - If `object[:rspec_examples]` is populated → renders the tree as nested lists, with the
     number of examples in the heading and an "expand all" link when there is more than one.
     Each example is a collapsible `<details>` element whose summary is the description, with a
     "pending" label for `x` variants; the code is highlighted with YARD's
     `html_syntax_highlight`, like the method source
   - If empty/nil and `YardRspec::Coverage.countable?(object)` → renders the "RSpec Examples:"
     heading with a red "no specs" label, and no list. No warning is logged at render time
   - If empty/nil and the method is not countable (attribute, alias, private method) → renders
     nothing, like the coverage gate that does not report such methods

3. **Coverage gate** (`rake yard:rspec_coverage`): parses `YardRspec::Config.files`, combined
   with the project's `.yardopts` the way `yard doc` does (so `--exclude` applies), takes
   `YardRspec::Coverage.countable_methods` and prints `RSpec coverage: X/Y (Z%)` plus a
   `file:line: Class#method` list of methods without examples (pending ones, `xit`, do not count). Exits 1 when coverage is
   below `YardRspec::Config.minimum_rspec_coverage` (default 100.0; override in the
   Rakefile). This is where missing specs are reported. It also lists the describe problems,
   which do not affect the exit status.

4. **Stats phase** (`yard stats`): `stats_for_rspec` is discovered automatically by YARD's
   `stats_for_*` convention. It counts `YardRspec::Coverage.countable_methods` with/without
   active (non-pending) `rspec_examples` and prints a row without touching `@total`/`@undocumented` (which drive
   the "% documented" percentage).

## Key design decisions

**`method[:rspec_examples]` as the data carrier**: examples are stored as custom metadata
on the YARD `MethodObject`. This is how YARD plugins share data between the parse and
render phases.

**Cross-scope fallback in `MethodDescription#find_in`**: when `#method` is not found as
`:instance`, we retry as `:class` (and vice versa). Specs often write `#` for class methods.

**Which methods count** (`YardRspec::Coverage.countable_methods`, used by both the coverage
gate and the stats row): public methods, except those defined in files matching
`Coverage::SPEC_FILE_PATTERN` (`%r{(?:^|/)spec/|_spec\.rb$|_helper\.rb$}`), attribute
readers/writers and aliases. Attributes and aliases have no behaviour of their own to spec.

**Stats do not affect "% documented"**: `stats_for_rspec` calls `log.puts` directly instead
of YARD's `output()`, so `@total` and `@undocumented` are never changed.

**Describe problems instead of warnings**: when a describe refers to a class or method that
cannot be found, the handler records it with `DescribeProblems.add` on the registry root
(`YARD::Registry.root[:rspec_describe_problems]`, so `Registry.clear` resets it). It never logs
a YARD warning, because YARD runs with `--fail-on-warning` (such as a project's `yard:coverage`)
would then fail. When the describe string has extra text beyond the method name
(e.g. `'#initialize via SomeFactory'`), no problem is recorded — these are intentionally
imprecise describe strings. "could not resolve class" is also skipped when the class is defined
in the running Ruby but not parsed (e.g. `describe YARD::CLI::Stats`), since describing a class
from another gem is not a typo.

## How to add new functionality

### New describe/context forms

The README section "Not supported" lists the RSpec keywords and forms that are deliberately not
recognized (`fit`, `pending`, `scenario`, `its`, shared examples, `xdescribe`, ...). Keep
that list in sync when adding support for one of them.

Extend `DescribeHandler#process` or `#process_nested_describes`. The data attachment point
is always `attach_examples_to(method_obj, block_body)`.

### New HTML output per method

Add a new section in `setup.rb` (`sections.place(:my_section).before(...)`) and a
corresponding `my_section.erb` template. Access per-method RSpec data via `object[:rspec_examples]`.

### New stats rows

Add a `stats_for_something` method to a new `lib/yard_rspec/something.rb` that does
`class_eval` on `YARD::CLI::Stats`. YARD discovers it automatically. Use `log.puts`
directly to avoid affecting the documentation percentage.

### New reports about describe blocks or missing specs

Do not log YARD warnings. Record describe block problems with `DescribeProblems.add` in
`DescribeHandler` (see `add_missing_method_problem`); the `yard:rspec_coverage` rake task prints
them. Missing-spec reporting also lives in that task, not in `setup.rb`.
For per-method rendering logic use `setup.rb`/`rspec_specs.erb`; `object` is the current
`YARD::MethodObject`.

## Testing conventions

- TDD: write the failing spec first, then implement.
- Describe what a method returns as `it 'returns ...'`, not `it 'is ...'`.
- Use `YARD::Registry.clear` + `YARD.parse_string(source)` to set up registry state.
- Test HTML output with `YARD::Templates::Engine.render(format: :html, template: :default,
  type: :method_details, markup: :none, object: method_obj)` — do **not** use
  `YARD::CLI::Yardoc.run` in specs (it fails on Ruby 4 due to Markdown/rdoc issues).
- To simulate a method defined in a spec file without breaking YARD rendering, use
  `method_obj.instance_variable_set(:@files, [['spec/support/helpers.rb', 1]])` rather
  than `allow(method_obj).to receive(:file)`.
- Set message expectations (`expect(...).to receive(...)`) before the action, not after.
- When invoking `yard:rspec_coverage` in a spec, make sure coverage meets the minimum (e.g. set
  `YardRspec::Config.minimum_rspec_coverage = 0.0`). The task calls `exit 1` otherwise, and
  RSpec then silently stops the run while reporting "0 failures".

## Running checks

```bash
bundle exec rspec
bundle exec rubocop --cache false lib/ spec/ templates/
bundle exec rake    # all checks, see below
```

`rake` (the default task) runs RuboCop, `bundle:audit`, `spec:coverage`, `yard:coverage` and
`yard:rspec_coverage`. It does not run `yard:doc`, which writes HTML to `doc/`; the specs already
render the template:

- `bundle:audit` (bundler-audit) checks `Gemfile.lock` against a local database of known gem
  vulnerabilities. It does not update that database: run `bundle exec rake bundle:audit:update`
  first to get the latest advisories (this needs network access).

- `spec:coverage` runs the specs with SimpleCov (`COVERAGE=true`). The minimum line and branch
  coverage is set in `spec/spec_helper.rb`. `rake_tasks_spec.rb` loads the rake file only once:
  loading a file again resets its line coverage.
- `yard:coverage` fails unless everything is documented and YARD logs no warnings.
- RuboCop uses its default configuration plus the performance, rake and rspec plugins, see
  `.rubocop.yml` for the few deviations. `.yardopts` selects Markdown through redcarpet.

- Run the entire build via build.sh

## Documentation
- Use terse documentation. If the method name is clear, no comments are needed
- Prefer an explanation with the @return over general method documentation. If the return can
  explain the logic.
- Prefer clear describe and it blocks in rspec over documentation

## Gotchas

- Do not load `lib/yard-rspec-coverage.rb` from `lib/yard_rspec/rake_tasks.rb` or the rake file at load
  time. That would register the describe handler and templates for every YARD run in the Rake
  process, such as a project's own `yard:coverage`; the project should choose that explicitly. The
  tasks load the plugin when they run. Consumers also declare the gem with `require: false`.

- YARD ignores `--plugin` when `YARD::CLI::Yardoc.run` is called in-process; only the `yard`
  executable loads plugins at boot. A Rake task must `require_relative '../yard-rspec-coverage'` itself.
  Specs that stub `Yardoc.run` cannot catch this; check in a separate Ruby process that the
  handler is loaded (see `rake_tasks_spec.rb`).

- `YARD::Logger.instance.puts` bypasses the log level check and always writes to `@io`.
  This means setting level to `ERROR` in spec_helper does not suppress `puts` output, but
  it does suppress `warn`.
- `YARD::CLI::Stats#output` increments `@total`/`@undocumented` only when `undoc` is
  passed. Never pass `undoc` from our stats method.
- The `stats_for_*` method name must start with `stats_for_` for YARD to discover it.
  Methods not in `STATS_ORDER` are printed after the standard rows.
- The describe handler is `namespace_only` — it only fires at the top namespace level of
  each file, not inside class bodies.
