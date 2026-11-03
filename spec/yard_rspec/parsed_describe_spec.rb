# frozen_string_literal: true

RSpec.describe YardRspec::ParsedDescribe do
  def parsed_describe(class_name, *entries)
    described_class.new(namespace: YARD::Registry.root, class_name: class_name,
                        location: 'widget_spec.rb:1', entries: entries)
  end

  def entry(description, examples = [], line = 2)
    described_class::Entry.new(description && YardRspec::MethodDescription.parse(description),
                               examples, "widget_spec.rb:#{line}")
  end

  before do
    YARD.parse_string(<<~RUBY)
      class Widget
        def spin; end
      end
    RUBY
  end

  describe '.new' do
    it 'keeps the location of the describe, for a problem recorded while attaching' do
      expect(parsed_describe('Widget').location).to eq('widget_spec.rb:1')
    end
  end

  describe '#attach' do
    it 'attaches the examples to the described method' do
      parsed_describe('Widget', entry('#spin', [{ description: 'spins', code: '' }])).attach

      expect(YARD::Registry.at('Widget#spin')[:rspec_examples])
        .to eq([{ description: 'spins', code: '' }])
    end

    it 'adds to the examples of an earlier describe of the same method' do
      parsed_describe('Widget', entry('#spin', [{ description: 'spins', code: '' }])).attach
      parsed_describe('Widget', entry('#spin', [{ description: 'stops', code: '' }])).attach

      expect(YARD::Registry.at('Widget#spin')[:rspec_examples])
        .to eq([{ description: 'spins', code: '' }, { description: 'stops', code: '' }])
    end

    it 'records a describe problem for a class that does not exist' do
      parsed_describe('Gadget', entry('#spin')).attach

      expect(YardRspec::DescribeProblems.all)
        .to eq(["widget_spec.rb:1: could not resolve class 'Gadget'"])
    end

    it 'records a describe problem for a method that does not exist, at its own line' do
      parsed_describe('Widget', entry('#wobble', [], 7)).attach

      expect(YardRspec::DescribeProblems.all)
        .to eq(["widget_spec.rb:7: could not find method '#wobble' on 'Widget'"])
    end

    it 'records a describe problem for a describe string that names no method' do
      parsed_describe('Widget', entry(nil, [], 3)).attach

      expect(YardRspec::DescribeProblems.all)
        .to eq(['widget_spec.rb:3: could not parse the method name of the describe'])
    end

    it 'records no problem for an imprecise describe string of a missing method' do
      parsed_describe('Widget', entry('#initialize via the factory')).attach

      expect(YardRspec::DescribeProblems.all).to eq([])
    end
  end
end
