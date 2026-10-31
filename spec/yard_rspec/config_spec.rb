# frozen_string_literal: true

RSpec.describe YardRspec::Config do
  describe '.minimum_rspec_coverage' do
    context 'when not configured' do
      it 'returns 100.0' do
        expect(described_class.minimum_rspec_coverage).to eq(100.0)
      end
    end

    context 'when configured' do
      before {described_class.minimum_rspec_coverage = 80.0}
      after  {described_class.minimum_rspec_coverage = nil}

      it 'returns the configured value' do
        expect(described_class.minimum_rspec_coverage).to eq(80.0)
      end
    end
  end

  describe '.minimum_rspec_coverage=' do
    after {described_class.minimum_rspec_coverage = nil}

    it 'sets the minimum coverage percentage' do
      described_class.minimum_rspec_coverage = 75.0
      expect(described_class.minimum_rspec_coverage).to eq(75.0)
    end
  end

  describe '.files' do
    context 'when not configured' do
      it 'returns the default glob pattern' do
        expect(described_class.files).to eq(['{lib,spec}/**/*.rb'])
      end
    end

    context 'when configured' do
      before {described_class.files = ['lib/**/*.rb']}
      after  {described_class.files = nil}

      it 'returns the configured file patterns' do
        expect(described_class.files).to eq(['lib/**/*.rb'])
      end
    end
  end

  describe '.files=' do
    after {described_class.files = nil}

    it 'sets the file glob patterns' do
      described_class.files = ['app/**/*.rb']
      expect(described_class.files).to eq(['app/**/*.rb'])
    end
  end
end
