# YARD-RSpec Plugin Implementation

## Overview

This YARD plugin successfully embeds RSpec examples alongside method documentation in YARD-generated documentation. When you document a method and have corresponding RSpec tests, those tests automatically appear in an "RSpec Examples" section in the method's documentation.

## Project Structure

```
yard-rspec-coverage/
├── lib/
│   ├── yard-rspec-coverage.rb   # Main plugin entry point
│   ├── yard_rspec/              # Handler, example extractor, coverage, stats, config, ...
│   └── tasks/
│       └── yard_rspec.rake      # yard:doc and yard:rspec_coverage tasks
├── templates/
│   └── default/
│       ├── method_details/html/ # rspec_specs.erb and setup.rb: the examples section
│       ├── layout/html/setup.rb # Adds the stylesheet and script to every page
│       └── fulldoc/html/        # css/rspec.css and js/rspec.js
├── spec/                        # The plugin's own specs
├── build.sh                     # Build script
├── Gemfile                      # Dependencies
├── yard-rspec-coverage.gemspec  # Gem specification
├── Rakefile                     # Rake tasks
└── README.md                    # Documentation
```

See AGENTS.md for the current file layout and how the plugin works.

## How It Works

### 1. Handler (lib/yard_rspec/handler.rb)

The handler is the core of the plugin. It:

- Registers to handle `describe` and `context` method calls
- Parses the RSpec describe blocks to extract:
  - The class/module being described
  - The method name (from `#method_name` or `.method_name` syntax)
  - All `it` and `specify` blocks within the describe
- Extracts from each `it` block:
  - The description (the string parameter)
  - The code (the block content)
- Stores this information as custom metadata on the method object using `method[:rspec_examples]`

### 2. Template (templates/default/method_details/html/)

The template system:

- `setup.rb`: Integrates the RSpec examples section into YARD's rendering pipeline
- `rspec_specs.erb`: Renders the RSpec examples in HTML format
- `layout/html/setup.rb` with `fulldoc/html/css/rspec.css` and `js/rspec.js`: styling and the
  "expand all" link

### 3. Main Plugin File (lib/yard-rspec-coverage.rb)

- Loads the handler
- Registers the custom template path with YARD

## Usage

### Running the Build

```bash
./build.sh
```

This will:
1. Install dependencies
2. Parse the example code
3. Generate documentation with embedded RSpec examples
4. Output to `doc/index.html`

### Using with Your Own Code

1. Write your Ruby code with YARD documentation
2. Write RSpec tests using the format:

```ruby
describe ClassName, '#method_name' do
  it "description of what it does" do
    # test code
  end
end
```

3. Generate documentation:

```bash
yardoc -e lib/yard-rspec-coverage.rb 'lib/**/*.rb' 'spec/**/*.rb'
```

## Supported RSpec Syntax

- `describe ClassName, '#method_name'` - for instance methods
- `describe ClassName, '.method_name'` - for class methods
- `it "description"` - test examples
- `specify "description"` - alias for `it`

## Example Output

For a method like:

```ruby
class String
  # Converts a string to pig latin
  def pig_latin
    self[1..-1] + self[0] + "ay"
  end
end

describe String, '#pig_latin' do
  it "converts 'hello' to pig latin" do
    "hello".pig_latin.should == "ellohay"
  end
end
```

The generated documentation will show:
- Method name and signature
- YARD documentation
- **RSpec Examples section** with:
  - "converts 'hello' to pig latin"
  - The test code

## Technical Details

### AST Parsing

The handler uses YARD's Ruby parser (based on Ripper) to parse the AST. Key node types:

- `:command` - Method calls like `describe` and `it`
- `:ident` - Identifiers (method names)
- `:list` - Parameter lists
- `:string_literal` - String values
- `:do_block` - Do...end blocks

### Method Resolution

The handler resolves methods by:
1. Extracting the class name from the first parameter
2. Extracting the method name from the second parameter
3. Determining scope (instance vs class) from the `#` or `.` prefix
4. Looking up the method in YARD's registry
5. Attaching the examples as custom metadata

## Known Limitations

1. **Ruby 4.0.0 Compatibility**: YARD 0.9.38 has some compatibility issues with Ruby 4.0.0's Marshal format. The plugin works correctly for parsing and extracting RSpec examples, but the standard YARD HTML generation may fail. We've included a demo generator (`generate_demo.rb`) as a workaround.

2. **Method Name Format**: The plugin expects the format `describe ClassName, '#method_name'`. Other formats may not be recognized.

3. **Nested Describes**: Currently only processes top-level describe blocks for methods.

## Future Enhancements

Potential improvements:
- Support for nested `context` blocks
- Support for `let` and `before` blocks
- Better handling of shared examples
- Integration with RSpec metadata
- Support for more flexible describe formats

## Testing

The plugin has been tested with the example code in `example/string_extensions.rb`, which includes:
- String extensions (pig_latin, reverse_upcase, palindrome?)
- Calculator class (add, subtract, multiply, divide)
- Various RSpec test scenarios

All examples are correctly extracted and displayed in the generated documentation.

