# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe YardRspec::DescribeHandler do
  def parse(source)
    YARD.parse_string(source)
  end

  describe '#process' do
    context 'with an instance method reference (#method_name)' do
      subject(:method_object) {YARD::Registry.at('Calculator#add')}

      before do
        parse(<<~RUBY)
          class Calculator
            # @return [Numeric]
            def add(a, b); a + b; end
          end

          describe Calculator, '#add' do
            it 'adds two positive numbers' do
              Calculator.new.add(2, 3).should == 5
            end
            it 'adds negative numbers' do
              Calculator.new.add(-2, -3).should == -5
            end
            it 'adds zero' do
              Calculator.new.add(5, 0).should == 5
            end
          end
        RUBY
      end

      it 'attaches the correct number of examples' do
        expect(method_object[:rspec_examples].count).to eq(3)
      end

      it 'extracts the descriptions in order' do
        descriptions = method_object[:rspec_examples].map {|example| example[:description]}
        expect(descriptions).to eq(
          ['adds two positive numbers', 'adds negative numbers', 'adds zero']
        )
      end

      it 'extracts non-empty code for each example' do
        codes = method_object[:rspec_examples].map {|example| example[:code]}
        expect(codes).to all(match(/\S/))
      end

      it 'extracts code that references the method under test' do
        first_example = method_object[:rspec_examples].first
        expect(first_example[:code]).to include('Calculator.new', 'add(2, 3)')
      end
    end

    context 'with a class method reference (.method_name)' do
      before do
        parse(<<~RUBY)
          class MathHelper
            # @return [Numeric]
            def self.square(n); n * n; end
          end

          describe MathHelper, '.square' do
            it 'squares a number' do
              MathHelper.square(3).should == 9
            end
          end
        RUBY
      end

      it 'attaches the example to the class method' do
        method_obj = YARD::Registry.at('MathHelper.square')
        expect(method_obj[:rspec_examples].count).to eq(1)
      end
    end

    context 'with the RSpec.describe ClassName nested form' do
      before do
        parse(<<~RUBY)
          module Sts
            class ActivationFrame
              # @return [Boolean]
              def eql?(other); self == other; end

              # @return [Integer]
              def hash; super; end
            end

            RSpec.describe ActivationFrame do
              describe '#eql?' do
                it 'returns true for equal objects' do
                  frame = ActivationFrame.new
                  expect(frame.eql?(frame)).to be(true)
                end
                it 'returns false for different objects' do
                  expect(ActivationFrame.new.eql?(ActivationFrame.new)).to be(false)
                end
              end

              describe '#hash' do
                it 'returns an integer' do
                  expect(ActivationFrame.new.hash).to be_a(Integer)
                end
              end
            end
          end
        RUBY
      end

      it 'attaches examples to the correct instance methods' do
        eql_method = YARD::Registry.at('Sts::ActivationFrame#eql?')
        expect(eql_method[:rspec_examples].count).to eq(2)
      end

      it 'extracts the descriptions for each nested describe' do
        descriptions = YARD::Registry.at('Sts::ActivationFrame#eql?')[:rspec_examples]
                                     .map {|example| example[:description]}
        expect(descriptions).to eq(
          ['returns true for equal objects', 'returns false for different objects']
        )
      end

      it 'attaches examples from separate nested describe blocks' do
        hash_method = YARD::Registry.at('Sts::ActivationFrame#hash')
        expect(hash_method[:rspec_examples].count).to eq(1)
      end
    end

    context 'with nested describes inside a context block' do
      before do
        parse(<<~RUBY)
          class Foo
            # @return [String]
            def bar; 'bar'; end
          end

          RSpec.describe Foo do
            context 'in some state' do
              describe '#bar' do
                it 'returns bar' do
                  expect(Foo.new.bar).to eq('bar')
                end
              end
            end
          end
        RUBY
      end

      it 'finds examples inside context blocks' do
        expect(YARD::Registry.at('Foo#bar')[:rspec_examples].count).to eq(1)
      end
    end

    context 'with multiple describe blocks for the same method' do
      before do
        parse(<<~RUBY)
          class Greeter
            # @return [String]
            def greet; 'hello'; end
          end

          describe Greeter, '#greet' do
            it 'returns a greeting' do
              Greeter.new.greet.should == 'hello'
            end
          end

          describe Greeter, '#greet' do
            it 'returns a string' do
              Greeter.new.greet.should be_a(String)
            end
          end
        RUBY
      end

      it 'accumulates examples from all describe blocks' do
        expect(YARD::Registry.at('Greeter#greet')[:rspec_examples].count).to eq(2)
      end
    end

    context 'when the describe block has no method parameter' do
      before do
        parse(<<~RUBY)
          class Widget; end

          describe Widget do
            it 'exists' do; end
          end
        RUBY
      end

      it 'does not attach examples to the class object' do
        expect(YARD::Registry.at('Widget')[:rspec_examples]).to be_nil
      end
    end

    context 'when the described method comes from an included module' do
      subject(:method_object) {YARD::Registry.at('Greeting#greet')}

      let(:source) do
        <<~RUBY
          module Greeting
            def greet; end
          end

          class Person
            include Greeting
          end

          RSpec.describe Person do
            describe '#greet' do
              it 'greets' do
                Person.new.greet
              end
            end
          end
        RUBY
      end

      it 'attaches the examples to the method of the module' do
        parse(source)

        expect(method_object[:rspec_examples])
          .to eq([{ description: 'greets', code: 'Person.new.greet' }])
      end

      it 'records no describe problem' do
        parse(source)

        expect(YardRspec::DescribeProblems.all).to eq([])
      end
    end

    context 'when the described class method comes from an extended module' do
      subject(:method_object) {YARD::Registry.at('Factory#build')}

      before do
        parse(<<~RUBY)
          module Factory
            def build; end
          end

          class Car
            extend Factory
          end

          describe Car, '.build' do
            it 'builds' do
              Car.build
            end
          end
        RUBY
      end

      it 'attaches the examples to the method of the module' do
        expect(method_object[:rspec_examples]).to eq([{ description: 'builds', code: 'Car.build' }])
      end
    end

    # YARD postpones files with unknown namespaces; listing the spec file first reproduces that.
    context 'when the spec file is parsed before the file that defines the class' do
      subject(:method_object) {YARD::Registry.at('Widget#spin')}

      let(:dir) {Dir.mktmpdir}

      after do
        FileUtils.remove_entry(dir)
      end

      before do
        File.write(File.join(dir, 'widget_spec.rb'), <<~RUBY)
          RSpec.describe Widget do
            describe '#spin' do
              it 'spins' do
                Widget.new.spin
              end
            end
          end
        RUBY
        File.write(File.join(dir, 'widget.rb'), <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
      end

      it 'attaches the examples once all files are parsed' do
        YARD.parse([File.join(dir, 'widget_spec.rb'), File.join(dir, 'widget.rb')])

        expect(method_object[:rspec_examples])
          .to eq([{ description: 'spins', code: 'Widget.new.spin' }])
      end

      it 'records no describe problem for the class or the method' do
        YARD.parse([File.join(dir, 'widget_spec.rb'), File.join(dir, 'widget.rb')])

        expect(YardRspec::DescribeProblems.all).to eq([])
      end
    end

    context 'when the referenced class is not in the registry' do
      let(:source) do
        <<~RUBY
          describe UnknownClass, '#some_method' do
            it 'does something' do; end
          end
        RUBY
      end

      it 'records a describe problem for the unresolvable class' do
        parse(source)

        expect(YardRspec::DescribeProblems.all)
          .to eq(["(stdin):1: could not resolve class 'UnknownClass'"])
      end

      # A warning would fail `yard --fail-on-warning`.
      it 'does not log a YARD warning' do
        expect(YARD::Logger.instance).not_to receive(:warn)

        parse(source)
      end
    end

    context 'when the referenced class is not a valid constant name' do
      it 'records a describe problem for the unresolvable class' do
        parse(<<~RUBY)
          describe String::widget, '#spin' do
            it 'spins' do; end
          end
        RUBY

        expect(YardRspec::DescribeProblems.all)
          .to eq(["(stdin):1: could not resolve class 'String::widget'"])
      end
    end

    context 'when the referenced class is loaded but not in the parsed sources' do
      it 'records no describe problem' do
        parse(<<~RUBY)
          describe YARD::CLI::Stats, '#stats_for_rspec' do
            it 'does something' do; end
          end
        RUBY

        expect(YardRspec::DescribeProblems.all).to eq([])
      end
    end

    context 'when the referenced method is not defined on the class' do
      let(:source) do
        <<~RUBY
          class Widget; end

          describe Widget, '#missing_method' do
            it 'does something' do; end
          end
        RUBY
      end

      it 'records a describe problem for the missing method' do
        parse(source)

        expect(YardRspec::DescribeProblems.all)
          .to eq(["(stdin):3: could not find method '#missing_method' on 'Widget'"])
      end

      # A warning would fail `yard --fail-on-warning`.
      it 'does not log a YARD warning' do
        expect(YARD::Logger.instance).not_to receive(:warn)

        parse(source)
      end
    end

    context 'when a nested describe references a missing method' do
      it 'records the describe problem with the inner describe line number, not the outer one' do
        parse(<<~RUBY)
          class Foo; end

          RSpec.describe Foo do
            context 'some context' do
              describe '#missing' do
                it 'does something' do; end
              end
            end
          end
        RUBY

        expect(YardRspec::DescribeProblems.all)
          .to eq(["(stdin):5: could not find method '#missing' on 'Foo'"])
      end
    end
  end

  describe 'HTML template rendering' do
    def render_method(method_obj)
      YARD::Templates::Engine.render(
        format: :html,
        template: :default,
        type: :method_details,
        markup: :none,
        object: method_obj
      )
    end

    context 'when a method has RSpec specs (HTML output)' do
      subject(:html) do
        parse(<<~RUBY)
          class Widget
            # @return [String]
            def name; end
          end
          describe Widget, '#name' do
            it 'returns a string' do
              expect(Widget.new.name).to eq('widget')
            end
          end
        RUBY
        render_method(YARD::Registry.at('Widget#name'))
      end

      it 'shows the number of examples in the heading' do
        expect(html).to include('<p class="tag_title">RSpec Examples (1):</p>')
      end

      it 'does not show the no specs label' do
        expect(html).not_to include('no specs')
      end

      it 'does not offer to expand all of a single example' do
        expect(html).not_to include('expand all')
      end

      it 'renders each description inside a <summary> element' do
        expect(html).to include('<summary>returns a string</summary>')
      end

      it 'highlights the example code like the method source' do
        expect(html)
          .to include("<pre class=\"example code\"><span class='id identifier rubyid_expect'>")
      end

      it 'renders examples as list items inside a <ul>' do
        expect(html).to match(/<ul class="rspec">\s*<li><details>/)
      end
    end

    context 'when a method has an excluded example (xit)' do
      subject(:html) do
        parse(<<~RUBY)
          class Widget
            # @return [String]
            def name; end
          end
          describe Widget, '#name' do
            it 'returns a string' do; end
            xit 'returns nil when unnamed' do; end
          end
        RUBY
        render_method(YARD::Registry.at('Widget#name'))
      end

      it 'labels the excluded example as pending' do
        expect(html).to include('<summary>returns nil when unnamed ' \
                                '<span class="rspec_label rspec_pending">pending</span>')
      end

      it 'does not label the active example as pending' do
        expect(html).to include('<summary>returns a string</summary>')
      end

      it 'offers to expand all examples' do
        expect(html).to include('<a href="#" class="rspec_toggle">expand all</a>')
      end
    end

    context 'when a method has examples inside a context' do
      subject(:html) do
        parse(<<~RUBY)
          class Widget
            # @return [String]
            def name; end
          end
          describe Widget, '#name' do
            context 'when unnamed' do
              it 'returns nil' do; end
            end
          end
        RUBY
        render_method(YARD::Registry.at('Widget#name'))
      end

      it 'renders the context as a group around its examples' do
        expect(html).to include('<li class="rspec_context"><span class="rspec_context_name">' \
                                'when unnamed</span><ul class="rspec"><li><details>')
      end
    end

    context 'when an attribute reader or alias has no RSpec specs' do
      subject(:html) do
        parse(<<~RUBY)
          class Gadget
            attr_reader :size

            # @return [Integer]
            def count; 0; end
            alias total count
          end
        RUBY
        [render_method(YARD::Registry.at('Gadget#size')),
         render_method(YARD::Registry.at('Gadget#total'))].join
      end

      it 'does not show the RSpec Examples section, as they need no specs' do
        expect(html).not_to include('RSpec Examples')
      end
    end

    context 'when an attribute reader has RSpec specs' do
      subject(:html) do
        parse(<<~RUBY)
          class Gadget
            attr_reader :size
          end
          describe Gadget, '#size' do
            it 'is the size' do; end
          end
        RUBY
        render_method(YARD::Registry.at('Gadget#size'))
      end

      it 'shows the examples' do
        expect(html).to include('<summary>is the size</summary>')
      end
    end

    context 'when a method has no RSpec specs' do
      subject(:html) do
        parse(<<~RUBY)
          class Gadget
            # @return [Integer]
            def count; 0; end
          end
        RUBY
        render_method(YARD::Registry.at('Gadget#count'))
      end

      it 'labels the RSpec Examples heading with no specs' do
        expect(html).to include('<p class="tag_title">RSpec Examples: ' \
                                '<span class="rspec_label rspec_missing">no specs</span></p>')
      end
    end
  end

  describe 'HTML assets' do
    it 'adds the stylesheet and script to every page' do
      layout = Object.new.extend(YARD::Templates::Engine.template(:default, :layout, :html))

      expect([layout.stylesheets.last, layout.javascripts.last])
        .to eq(%w[css/rspec.css js/rspec.js])
    end

    it 'ships the stylesheet and script with the documentation' do
      fulldoc = YARD::Templates::Engine.template(:default, :fulldoc, :html)

      expect(%w[css/rspec.css js/rspec.js].map {|file| fulldoc.find_file(file)})
        .to all(be_a(String))
    end
  end
end
