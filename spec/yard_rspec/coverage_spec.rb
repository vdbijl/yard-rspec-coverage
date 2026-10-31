# frozen_string_literal: true

RSpec.describe YardRspec::Coverage do
  describe '.countable_methods' do
    before do
      YARD.parse_string(<<~RUBY)
        class Example
          attr_reader :name
          attr_accessor :size

          def run; end

          def stop; end
          alias halt stop

          private

          def helper; end
        end
      RUBY
    end

    it 'returns the public methods, leaving out attributes and aliases' do
      expect(described_class.countable_methods.map(&:path)).to eq(['Example#run', 'Example#stop'])
    end

    context 'when a public method is defined in a spec support file' do
      before do
        YARD::Registry.at('Example#run')
                      .instance_variable_set(:@files, [['spec/support/helpers.rb', 1]])
      end

      it 'leaves it out' do
        expect(described_class.countable_methods.map(&:path)).to eq(['Example#stop'])
      end
    end
  end

  describe '.countable?' do
    def countable?(path)
      described_class.countable?(YARD::Registry.at(path))
    end

    before do
      YARD.parse_string(<<~RUBY)
        class Example
          attr_reader :name

          def run; end
          alias halt run

          private

          def helper; end
        end
      RUBY
    end

    it 'returns true for a public method' do
      expect(countable?('Example#run')).to be true
    end

    it 'returns false for an attribute reader' do
      expect(countable?('Example#name')).to be false
    end

    it 'returns false for an alias' do
      expect(countable?('Example#halt')).to be false
    end

    it 'returns false for a private method' do
      expect(countable?('Example#helper')).to be false
    end

    it 'returns false for a method defined in a spec support file' do
      YARD::Registry.at('Example#run')
                    .instance_variable_set(:@files, [['spec/support/helpers.rb', 1]])

      expect(countable?('Example#run')).to be false
    end
  end

  describe '.examples' do
    let(:nodes) do
      [{ description: 'runs', code: '' },
       { description: 'when empty', children: [{ description: 'is skipped', code: '' }] }]
    end

    it 'returns the examples at any depth, without the contexts' do
      expect(described_class.examples(nodes))
        .to eq([{ description: 'runs', code: '' }, { description: 'is skipped', code: '' }])
    end
  end

  describe '.covered?' do
    def covered?(source)
      YARD::Registry.clear
      YARD.parse_string(source)
      described_class.covered?(YARD::Registry.at('Widget#spin'))
    end

    it 'returns true when the method has an example' do
      expect(covered?(<<~RUBY)).to be true
        class Widget
          def spin; end
        end
        describe Widget, '#spin' do
          it 'spins' do; end
        end
      RUBY
    end

    it 'returns true when the method has an example inside a context' do
      expect(covered?(<<~RUBY)).to be true
        class Widget
          def spin; end
        end
        describe Widget, '#spin' do
          context 'when fast' do
            it 'spins quickly' do; end
          end
        end
      RUBY
    end

    it 'returns false when the method has no examples' do
      expect(covered?(<<~RUBY)).to be false
        class Widget
          def spin; end
        end
      RUBY
    end

    it 'returns false when all examples are pending' do
      expect(covered?(<<~RUBY)).to be false
        class Widget
          def spin; end
        end
        describe Widget, '#spin' do
          xit 'spins' do; end
          context 'when fast' do
            xit 'spins quickly' do; end
          end
        end
      RUBY
    end

    it 'returns true when at least one example is not pending' do
      expect(covered?(<<~RUBY)).to be true
        class Widget
          def spin; end
        end
        describe Widget, '#spin' do
          xit 'spins' do; end
          it 'stops' do; end
        end
      RUBY
    end
  end
end
