# frozen_string_literal: true

RSpec.describe YardRspec::MethodDescription do
  describe '#initialize' do
    subject(:description) {described_class.new(name: 'run', scope: :instance, imprecise: false)}

    it 'keeps the name and scope' do
      expect([description.name, description.scope]).to eq(['run', :instance])
    end
  end

  describe '.parse' do
    it 'parses an instance method' do
      description = described_class.parse('#run')

      expect([description.name, description.scope]).to eq(['run', :instance])
    end

    it 'parses a class method' do
      description = described_class.parse('.build')

      expect([description.name, description.scope]).to eq(['build', :class])
    end

    it 'returns nil for a string that names no method' do
      expect(described_class.parse('when the widget is empty')).to be_nil
    end

    it 'parses an operator method' do
      expect(described_class.parse('#<=>').name).to eq('<=>')
    end
  end

  describe '#name' do
    it 'returns the method name without the scope prefix' do
      expect(described_class.parse('#run via SomeFactory').name).to eq('run')
    end
  end

  describe '#scope' do
    it 'returns :instance for a # prefix' do
      expect(described_class.parse('#run').scope).to eq(:instance)
    end

    it 'returns :class for a . prefix' do
      expect(described_class.parse('.build').scope).to eq(:class)
    end
  end

  describe '#imprecise?' do
    it 'returns false when the string only names the method' do
      expect(described_class.parse('#initialize')).not_to be_imprecise
    end

    it 'returns true when the string has extra text after the method name' do
      expect(described_class.parse('#initialize via SomeFactory')).to be_imprecise
    end
  end

  describe '#to_s' do
    it 'writes an instance method with a # prefix' do
      expect(described_class.parse('#run').to_s).to eq('#run')
    end

    it 'writes a class method with a . prefix' do
      expect(described_class.parse('.build').to_s).to eq('.build')
    end
  end

  describe '#find_in' do
    subject(:namespace) {YARD::Registry.at('Widget')}

    before do
      YARD.parse_string(<<~RUBY)
        module Spinnable
          def spin; end
        end

        class Widget
          include Spinnable

          def run; end

          def self.build; end

          private

          def hidden; end
        end
      RUBY
    end

    it 'finds an instance method of the namespace' do
      expect(described_class.parse('#run').find_in(namespace).path).to eq('Widget#run')
    end

    it 'finds a class method of the namespace' do
      expect(described_class.parse('.build').find_in(namespace).path).to eq('Widget.build')
    end

    it 'finds a private method' do
      expect(described_class.parse('#hidden').find_in(namespace).path).to eq('Widget#hidden')
    end

    it 'finds a method of an included module, on the module itself' do
      expect(described_class.parse('#spin').find_in(namespace).path).to eq('Spinnable#spin')
    end

    it 'falls back to the other scope when the prefix does not match' do
      expect(described_class.parse('#build').find_in(namespace).path).to eq('Widget.build')
    end

    it 'returns nil when the method does not exist' do
      expect(described_class.parse('#missing').find_in(namespace)).to be_nil
    end
  end
end
