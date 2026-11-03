# frozen_string_literal: true

RSpec.describe YardRspec::NestedMethodDescribes do
  def block_body(source)
    YARD::Parser::Ruby::RubyParser.new(source, 'widget_spec.rb').parse.enumerator.first.block.last
  end

  describe '#initialize' do
    it 'takes the body of the outer describe block' do
      expect(described_class.new(nil)).to be_a(described_class)
    end
  end

  describe '#each' do
    it 'yields the description and line of each nested method describe, nil if unparsable' do
      body = block_body(<<~RUBY)
        describe Widget do
          context 'when idle' do
            describe '#spin' do; end
          end
          describe '.build' do; end
          describe 'a topic' do; end
          describe '#' do; end
        end
      RUBY

      yielded = described_class.new(body).map do |description, _body, line|
        [description&.to_s, line]
      end

      expect(yielded).to eq([['#spin', 3], ['.build', 5], [nil, 7]])
    end

    it 'keeps a quote inside the description' do
      body = block_body(<<~RUBY)
        describe Widget do
          describe "#spin's" do; end
        end
      RUBY

      expect(described_class.new(body).map {|description, _body, _line| description.to_s})
        .to eq(["#spin's"])
    end

    it 'yields a nested describe with metadata after the description' do
      body = block_body(<<~RUBY)
        describe Widget do
          describe '#spin', :slow do; end
        end
      RUBY

      expect(described_class.new(body).map {|description, _body, _line| description.to_s})
        .to eq(['#spin'])
    end

    it 'does not yield an example whose description starts with #' do
      body = block_body(<<~RUBY)
        describe Widget do
          it '#spin is fast' do; end
        end
      RUBY

      expect(described_class.new(body).to_a).to eq([])
    end

    it 'returns an enumerator without a block' do
      body = block_body(<<~RUBY)
        describe Widget do
          describe '#spin' do; end
        end
      RUBY

      enumerator = described_class.new(body).each

      expect(enumerator.map {|description, _body, line| [description.to_s, line]})
        .to eq([['#spin', 2]])
    end
  end
end
