# yard-rspec-coverage

A YARD plugin that embeds RSpec examples alongside method documentation in the generated YARD
documentation.

## Overview

This plugin allows you to see RSpec test examples directly in your YARD-generated documentation.
When you document a method and have corresponding RSpec tests, those tests will automatically appear
in a "RSpec Examples" section in the method's documentation.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'yard-rspec-coverage'
```

Or install it yourself:

```bash
gem install yard-rspec-coverage
```

## Usage

### Basic Usage

1. Write your Ruby code with YARD documentation comments
2. Write RSpec tests using `describe` and `it` blocks
3. Generate documentation with the plugin loaded:

```bash
yard doc --plugin rspec-coverage 'lib/**/*.rb' 'spec/**/*.rb'
```

List the spec files explicitly: without file arguments (or files in `.yardopts`) YARD only parses
`lib/` and `app/`, so it finds no examples.

### Rake tasks

Declare the gem with `require: false` in your Gemfile, so you choose which YARD runs use the
plugin; `Bundler.require` would load it into every YARD run in the process. Then require the tasks
from your project's `Rakefile`:

```ruby
require 'yard_rspec/rake_tasks'

YardRspec::Config.minimum_rspec_coverage = 80.0 # default: 100.0
YardRspec::Config.files = ['{lib,spec}/**/*.rb'] # default
```

This defines two tasks:

- `rake yard:doc` generates the documentation with the `rspec-coverage` plugin. It writes to `doc/`, like
  other YARD tasks such as `yard:coverage`, so run it last.
- `rake yard:rspec_coverage` lists the public methods without RSpec examples and fails when the
  coverage is below `minimum_rspec_coverage`. Attribute readers/writers and aliases are not
  counted. It also lists describe blocks that name a class or method that cannot be found, such
  as a typo, without failing.

The plugin never logs YARD warnings, so it is safe in YARD runs with `--fail-on-warning`.

Or use the provided build script:

```bash
./build.sh
```

### Example

Given this code:

```ruby
class String
  # Converts a string to pig latin
  # 
  # @return [String] the pig latin version of the string
  def pig_latin
    self[1..-1] + self[0] + "ay"
  end
end

describe String, '#pig_latin' do
  it "converts 'hello' to pig latin" do
    "hello".pig_latin.should == "ellohay"
  end

  it "works with single character strings" do
    "a".pig_latin.should == "aay"
  end
end
```

The generated documentation for `String#pig_latin` will include an "RSpec Examples" section showing both test cases.

## How It Works

The plugin consists of four main components:

1. **Handler** (`lib/yard_rspec/handler.rb`): Parses RSpec `describe` blocks and extracts `it` examples
2. **Template** (`templates/default/method_details/html/rspec_specs.erb`): Displays the examples in the documentation
3. **Setup** (`templates/default/method_details/html/setup.rb`): Integrates the template into YARD's rendering pipeline
4. **Assets** (`templates/default/fulldoc/html/`): A stylesheet and a script for the "expand all" link

Each example shows its description and its syntax-highlighted code. Pending
examples are labelled "pending", and a public method without specs gets a red "no specs" label.

## RSpec Format Support

The plugin supports the following RSpec syntax:

- `describe ClassName, '#method_name'` for instance methods
- `describe ClassName, '.method_name'` for class methods
- `it "description"` blocks within describe blocks
- `specify "description"` and `example "description"` blocks (aliases for `it`)
- `xit`, `xspecify` and `xexample` blocks (excluded examples), shown with a "(pending)" suffix.
  They do not count as coverage: a method with only pending examples is reported as without
  specs.
- nested `context "..."` and `describe "..."` blocks, shown as groups of examples

### Not supported

These RSpec constructs are not recognized. Examples written with them do not appear in the
documentation and do not count towards RSpec coverage.

- Examples that are not written as a command without parentheses followed by a block: `it('x') {}`
  the one-liner `it {is_expected.to be_ok}` and `it do ... end` without a description.
- Focused examples: `fit`, `fspecify` and `fexample`. A focused example makes RSpec skip the rest
  of the suite, so it should not be committed; the plugin does not document it.
- The `pending` and `skip` keywords.
- Capybara's `scenario` (and `feature` as a group), and the `its` method of rspec-its.
- Shared examples: `it_behaves_like`, `it_should_behave_like`, `include_examples` and
  `include_context` are ignored, so the examples of a `shared_examples` group are not attributed to
  the methods that use it. The examples inside a `shared_examples` block are attributed to the
  enclosing method, as if they were written directly in the describe block.
- Focused and excluded groups: `fdescribe`, `xdescribe`, `fcontext`, `xcontext` and `example_group`
  are not recognized as groups. Their examples are still collected, but without the group, so the
  group's description is lost. A `describe '#method'` written with one of these keywords is not
  linked to the method.

Limitations of the supported constructs:

- Only the text before the first interpolation of a description is kept: `it "loop #{index}"`
  is shown as `loop `. Examples generated in a loop are listed once.
- Examples whose description is not a string literal are shown as `example`.

## Development

To test the plugin with the example code:

```bash
bundle install
./build.sh
```

Then open `doc/index.html` in your browser to see the generated documentation.

Run all checks (RuboCop, a dependency vulnerability audit, the specs with SimpleCov, YARD
documentation coverage and RSpec coverage) with:

```bash
bundle exec rake
```

### Releasing

Update the version in `yard-rspec-coverage.gemspec` and `CHANGELOG.md`, then push a matching tag:

```bash
git tag v0.1.3
git push origin v0.1.3
```

The release workflow runs all checks and publishes the gem to rubygems.org with
[Trusted Publishing](https://guides.rubygems.org/trusted-publishing/), so no API key is stored.

## License

MIT License

## Credits

Inspired by the [yard-spec-plugin](https://github.com/lsegal/yard-spec-plugin) by Loren Segal.
