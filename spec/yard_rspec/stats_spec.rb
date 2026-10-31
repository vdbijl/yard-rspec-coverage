# frozen_string_literal: true

RSpec.describe YARD::CLI::Stats, '#stats_for_rspec extension' do
  def parse(source)
    YARD::Registry.clear
    YARD.parse_string(source)
  end

  let(:stats) do
    instance = described_class.new(false)
    instance.instance_variable_set(:@total, 0)
    instance.instance_variable_set(:@undocumented, 0)
    instance
  end

  let(:log_output) do
    lines = []
    allow(YARD::Logger.instance).to receive(:puts) {|msg| lines << msg.to_s}
    stats.stats_for_rspec
    lines.join("\n")
  end

  before do
    parse(<<~RUBY)
      class Example
        # @return [String]
        def covered_method; end

        # @return [Integer]
        def uncovered_method; end

        private

        def private_method; end
      end

      describe Example, '#covered_method' do
        it 'works' do; end
      end
    RUBY
  end

  describe '#stats_for_rspec' do
    it 'labels the row "RSpec specs:"' do
      expect(log_output).to include('RSpec specs:')
    end

    it 'reports the number of covered public lib methods' do
      expect(log_output).to match(/RSpec specs:.*\b1\b/)
    end

    it 'reports the number of uncovered public lib methods' do
      expect(log_output).to include('1 without specs')
    end

    it 'excludes private methods from the count' do
      expect(log_output).not_to include('2 without specs')
    end

    context 'when the class has attributes and aliases without specs' do
      before do
        YARD.parse_string(<<~RUBY)
          class Example
            attr_reader :name
            alias covered_alias covered_method
          end
        RUBY
      end

      it 'leaves them out of the count' do
        expect(log_output).to include('1 without specs')
      end
    end

    context 'when all methods have examples' do
      before do
        YARD.parse_string(<<~RUBY)
          describe Example, '#uncovered_method' do
            it 'works' do; end
          end
        RUBY
      end

      it 'reports only the number of covered methods' do
        expect(log_output).to eq('RSpec specs:     2')
      end
    end

    context 'when a method only has pending examples' do
      before do
        YARD.parse_string(<<~RUBY)
          describe Example, '#uncovered_method' do
            xit 'works later' do; end
          end
        RUBY
      end

      it 'does not count it as covered' do
        expect(log_output).to include('1 without specs')
      end
    end

    context 'when the row is logged' do
      before do
        log_output
      end

      it 'does not change the total counter of the documentation percentage' do
        expect(stats.instance_variable_get(:@total)).to eq 0
      end

      it 'does not change the undocumented counter of the documentation percentage' do
        expect(stats.instance_variable_get(:@undocumented)).to eq 0
      end
    end
  end
end
