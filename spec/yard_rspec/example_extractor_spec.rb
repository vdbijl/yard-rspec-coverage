# frozen_string_literal: true

RSpec.describe YardRspec::ExampleExtractor do
  before {YARD::Registry.clear}

  describe '#initialize' do
    context 'when the describe has no block' do
      subject(:extractor) {described_class.new(described_class::EMPTY_BODY)}

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

      it 'returns Example objects' do
        expect(examples).to all(be_a(YardRspec::Example))
      end

      it 'extracts the descriptions in order' do
        expect(examples.map(&:description))
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
        expect(examples.map(&:description))
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
        expect(examples.map {|example| [example.description, example.pending?]})
          .to eq([['is active', false],
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

        expect(examples).to match([an_example('raises on a second run', code)])
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

      it 'returns one example group for the context block' do
        expect(examples).to match([an_example_group('when conditions are met',
                                                    an_example('succeeds'),
                                                    an_example('returns a value'))])
      end

      it 'nests the examples under the example group' do
        children = examples.first.children
        expect(children.map(&:description)).to eq(['succeeds', 'returns a value'])
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

      it 'returns one example group per context block' do
        expect(examples.map(&:description))
          .to eq(['when conditions are met', 'when conditions are not met'])
      end

      it 'nests examples inside their own context' do
        expect(examples.map {|node| node.children.map(&:description)})
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
        inner = an_example_group('and input is valid', an_example('returns true'))
        outer = an_example_group('when conditions are met', inner)

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

      it 'returns a direct example followed by an example group' do
        direct = an_example('basic behavior')
        group = an_example_group('in special state', an_example('behaves differently'))

        expect(examples).to match([direct, group])
      end
    end

    # RSpec reports an example without a block as pending: "Not yet implemented".
    context 'with an example without a block' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it 'runs twice'
          end
        RUBY
      end

      it 'returns it as a pending example without code' do
        expect(examples).to match([an_example('runs twice', pending: true)])
      end
    end

    context 'with a context without examples' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            context 'when stopped' do
            end
            it 'runs' do; end
          end
        RUBY
      end

      it 'leaves the context out' do
        expect(examples).to match([an_example('runs')])
      end
    end

    context 'with let, before and subject next to the examples' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            let(:speed) { 3 }
            subject(:runner) { Subject.new }
            before do
              runner.prepare
            end
            it 'runs' do; end
          end
        RUBY
      end

      it 'returns only the examples' do
        expect(examples).to match([an_example('runs')])
      end
    end

    # The README section "Not supported" lists these; a change in behavior should be deliberate.
    context 'with constructs that are not recognized as examples' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it('with parentheses') { }
            it { is_expected.to be_ok }
            it do; end
            fit 'focused' do; end
            fspecify 'focused specify' do; end
            fexample 'focused example' do; end
            pending 'pending keyword' do; end
            skip 'skip keyword' do; end
            scenario 'capybara' do; end
            its(:size) { is_expected.to eq(1) }
            it_behaves_like 'a runner'
            it_should_behave_like 'a runner'
            include_examples 'a runner'
            include_context 'a runner'
          end
        RUBY
      end

      it 'returns no examples' do
        expect(examples).to eq([])
      end
    end

    context 'with focused and excluded groups, which are not recognized as groups' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            xdescribe 'excluded' do
              it 'in xdescribe' do; end
            end
            fcontext 'focused' do
              it 'in fcontext' do; end
            end
            example_group 'old style' do
              it 'in example_group' do; end
            end
          end
        RUBY
      end

      it 'returns their examples without the group' do
        expect(examples.map(&:description))
          .to eq(['in xdescribe', 'in fcontext', 'in example_group'])
      end
    end

    # As the README says: their examples are listed as if they were written in the describe block.
    context 'with examples inside shared_examples' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            shared_examples 'a runner' do
              it 'runs' do; end
            end
          end
        RUBY
      end

      it 'returns the examples without a group for shared_examples' do
        expect(examples).to match([an_example('runs')])
      end
    end

    context 'with an example whose code has a blank line' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it 'runs twice' do
              subject.run

              subject.run
            end
          end
        RUBY
      end

      it 'removes the common indentation of the other lines' do
        expect(examples.first.code).to eq("subject.run\n\nsubject.run")
      end
    end

    context 'with a context without a block' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            context 'when stopped'
            it 'runs' do; end
          end
        RUBY
      end

      it 'leaves the context out' do
        expect(examples).to match([an_example('runs')])
      end
    end

    context 'with interpolated descriptions' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~'RUBY')
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it "runs #{count} times" do; end
            it "#{count} runs" do; end
          end
        RUBY
      end

      it 'returns the descriptions as written, with the interpolation' do
        expect(examples.map(&:description))
          .to eq(["runs \#{count} times", "\#{count} runs"])
      end
    end

    context 'with a description split over several lines' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~'RUBY')
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it 'runs once '\
               'and then ' \
               "#{count} times" do; end
          end
        RUBY
      end

      it 'returns the parts joined, as RSpec does' do
        expect(examples.map(&:description))
          .to eq(["runs once and then \#{count} times"])
      end
    end

    context 'with a description that is not a string literal or is empty' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string(<<~RUBY)
          class Subject
            def run; end
          end
          describe Subject, '#run' do
            it :runs do; end
            it '' do; end
            it format('runs %s', 1) do; end
          end
        RUBY
      end

      it 'returns example as the description, also for a string inside another argument' do
        expect(examples.map(&:description)).to eq(%w[example example example])
      end
    end

    context 'with an example on the first line of the source' do
      subject(:examples) {YARD::Registry.at('Subject#run')[:rspec_examples]}

      before do
        YARD.parse_string('class Subject; def run; end; end; '\
                          "describe Subject, '#run' do it 'runs' do run end end")
      end

      it 'returns the code of the example' do
        expect(examples).to match([an_example('runs', 'run')])
      end
    end
  end
end
