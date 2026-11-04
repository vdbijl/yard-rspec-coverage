# frozen_string_literal: true

RSpec.describe YardRspec::DescribeProblems do
  describe '.all' do
    context 'when no problems are added' do
      it 'returns an empty list' do
        expect(described_class.all).to eq([])
      end
    end

    context 'when problems are added' do
      before do
        described_class.add("spec/widget_spec.rb:9: could not find method '#spin' on 'Widget'")
        described_class.add("spec/car_spec.rb:3: could not resolve class 'Car'")
      end

      it 'returns them sorted' do
        expect(described_class.all)
          .to eq(["spec/car_spec.rb:3: could not resolve class 'Car'",
                  "spec/widget_spec.rb:9: could not find method '#spin' on 'Widget'"])
      end
    end

    context 'when the registry is cleared after adding a problem' do
      before do
        described_class.add("spec/car_spec.rb:3: could not resolve class 'Car'")
        YARD::Registry.clear
      end

      it 'returns an empty list' do
        expect(described_class.all).to eq([])
      end
    end
  end

  describe '.add' do
    it 'adds the problem to the list' do
      described_class.add("spec/car_spec.rb:3: could not resolve class 'Car'")

      expect(described_class.all).to eq(["spec/car_spec.rb:3: could not resolve class 'Car'"])
    end

    it 'returns nil, not the list of problems that the registry keeps' do
      expect(described_class.add("spec/car_spec.rb:3: could not resolve class 'Car'")).to be_nil
    end
  end

  describe '.recording_failure' do
    it 'runs the block' do
      expect {|block| described_class.recording_failure('spec/car_spec.rb:3', &block)}
        .to yield_control
    end

    it 'records an error raised by the block as a problem' do
      described_class.recording_failure('spec/car_spec.rb:3') {raise ArgumentError, 'broken'}

      expect(described_class.all)
        .to eq(['spec/car_spec.rb:3: could not process the describe: ArgumentError: broken'])
    end
  end
end
