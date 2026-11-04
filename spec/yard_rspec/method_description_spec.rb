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

    it 'returns nil when only a later line of the text starts with # or .' do
      expect(described_class.parse("when the widget\n#run")).to be_nil
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

    it 'falls back to the class scope when a # prefix names a class method' do
      expect(described_class.parse('#build').find_in(namespace).path).to eq('Widget.build')
    end

    it 'falls back to the instance scope when a . prefix names an instance method' do
      expect(described_class.parse('.run').find_in(namespace).path).to eq('Widget#run')
    end

    it 'returns nil when the method does not exist' do
      expect(described_class.parse('#missing').find_in(namespace)).to be_nil
    end

    # RSpec specs often describe the constructor as '.new', but YARD documents #initialize.
    context 'when the description names new' do
      before do
        YARD.parse_string(<<~RUBY)
          class Gizmo
            def initialize; end
          end

          class Factory
            def self.new; end

            def initialize; end
          end
        RUBY
      end

      it 'finds initialize for .new' do
        expect(described_class.parse('.new').find_in(YARD::Registry.at('Gizmo')).path)
          .to eq('Gizmo#initialize')
      end

      it 'finds initialize for #new' do
        expect(described_class.parse('#new').find_in(YARD::Registry.at('Gizmo')).path)
          .to eq('Gizmo#initialize')
      end

      it 'returns nil for another missing method, not initialize' do
        expect(described_class.parse('#missing').find_in(YARD::Registry.at('Gizmo'))).to be_nil
      end

      it 'finds a class method new that the class defines itself' do
        expect(described_class.parse('.new').find_in(YARD::Registry.at('Factory')).path)
          .to eq('Factory.new')
      end
    end

    context 'when a superclass has an instance method and a class method with the same name' do
      subject(:namespace) {YARD::Registry.at('Gizmo')}

      before do
        YARD.parse_string(<<~RUBY)
          class Base
            def call; end

            def self.call; end
          end

          class Gizmo < Base; end
        RUBY
      end

      it 'finds the inherited instance method for a # prefix' do
        expect(described_class.parse('#call').find_in(namespace).path).to eq('Base#call')
      end

      it 'finds the inherited class method for a . prefix' do
        expect(described_class.parse('.call').find_in(namespace).path).to eq('Base.call')
      end
    end

    context 'when an instance method and a class method have the same name' do
      subject(:namespace) {YARD::Registry.at('Gadget')}

      before do
        YARD.parse_string(<<~RUBY)
          class Gadget
            def self.call; end

            def call; end
          end
        RUBY
      end

      it 'finds the instance method for a # prefix' do
        expect(described_class.parse('#call').find_in(namespace).path).to eq('Gadget#call')
      end

      it 'finds the class method for a . prefix' do
        expect(described_class.parse('.call').find_in(namespace).path).to eq('Gadget.call')
      end
    end
  end
end
