# frozen_string_literal: true

RSpec.describe YardRspec::ExampleExtractor do
  before {YARD::Registry.clear}

  describe '#initialize' do
    context 'when block_node is nil' do
      subject(:extractor) {described_class.new(nil)}

      it 'creates an extractor that returns an empty array on extract' do
        expect(extractor.extract).to eq([])
      end
    end
  end

  describe '#extract' do
    context 'with examples directly in the describe block' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            it 'does the thing' do; end
            it 'does another thing' do; end
          end
        RUBY
      end

      it 'returns example nodes with description and code keys' do
        expect(examples).to all(include(:description, :code))
      end

      it 'extracts the descriptions in order' do
        expect(examples.map {|example| example[:description]})
          .to eq(['does the thing', 'does another thing'])
      end
    end

    context 'with the it, specify and example keywords' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            it 'uses it' do; end
            specify 'uses specify' do; end
            example 'uses example' do; end
          end
        RUBY
      end

      it 'extracts the examples of all three keywords in order' do
        expect(examples.map {|example| example[:description]})
          .to eq(['uses it', 'uses specify', 'uses example'])
      end
    end

    context 'with excluded examples (xit, xspecify, xexample)' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            it 'is active' do; end
            xit 'is disabled with xit' do; end
            xspecify 'is disabled with xspecify' do; end
            xexample 'is disabled with xexample' do; end
          end
        RUBY
      end

      it 'extracts them in order, marking only the excluded ones as pending' do
        expect(examples.map {|example| [example[:description], example[:pending]]})
          .to eq([['is active', nil],
                  ['is disabled with xit', true],
                  ['is disabled with xspecify', true],
                  ['is disabled with xexample', true]])
      end
    end

    context 'with a multi-line example' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            it 'raises on a second run' do
              subject.run
              expect {subject.run}.to raise_error RuntimeError,
                'Already running.'
            end
          end
        RUBY
      end

      it 'removes the common indentation of all lines, keeping the relative indentation' do
        code = <<~RUBY.chomp
          subject.run
          expect {subject.run}.to raise_error RuntimeError,
            'Already running.'
        RUBY

        expect(examples).to eq([{ description: 'raises on a second run', code: }])
      end
    end

    context 'with examples inside a context block' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            context 'when conditions are met' do
              it 'succeeds' do; end
              it 'returns a value' do; end
            end
          end
        RUBY
      end

      it 'returns one context node for the context block' do
        expect(examples).to match([include(description: 'when conditions are met')])
      end

      it 'nests the examples under the context node' do
        children = examples.first[:children]
        expect(children.map {|child| child[:description]}).to eq(['succeeds', 'returns a value'])
      end
    end

    context 'with multiple context blocks' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            context 'when conditions are met' do
              it 'succeeds' do; end
            end
            context 'when conditions are not met' do
              it 'raises an error' do; end
            end
          end
        RUBY
      end

      it 'returns one node per context block' do
        expect(examples.map {|node| node[:description]})
          .to eq(['when conditions are met', 'when conditions are not met'])
      end

      it 'nests examples inside their own context' do
        expect(examples.map {|node| node[:children].map {|child| child[:description]}})
          .to eq([['succeeds'], ['raises an error']])
      end
    end

    context 'with nested context blocks' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            context 'when conditions are met' do
              context 'and input is valid' do
                it 'returns true' do; end
              end
            end
          end
        RUBY
      end

      it 'nests the inner context inside the outer context' do
        inner = include(description: 'and input is valid',
                        children: [include(description: 'returns true')])
        outer = include(description: 'when conditions are met', children: [inner])

        expect(examples).to match([outer])
      end
    end

    context 'with mixed direct and context examples' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            # @return [void]
            def run; end
          end
          describe Subject, '#run' do
            it 'basic behavior' do; end
            context 'in special state' do
              it 'behaves differently' do; end
            end
          end
        RUBY
      end

      it 'returns a direct example node followed by a context node' do
        direct = include(description: 'basic behavior', code: '')
        group = include(description: 'in special state',
                        children: [include(description: 'behaves differently')])

        expect(examples).to match([direct, group])
      end
    end
  end
end
