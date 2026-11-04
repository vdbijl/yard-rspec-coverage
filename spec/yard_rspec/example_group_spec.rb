# frozen_string_literal: true

RSpec.describe YardRspec::ExampleGroup do
  let(:spins) {YardRspec::Example.new(description: 'spins', code: '')}
  let(:stops) {YardRspec::Example.new(description: 'stops', code: '', pending: true)}

  describe '.new' do
    subject(:group) {described_class.new(description: 'when idle', children: [spins])}

    it 'keeps the description' do
      expect(group.description).to eq('when idle')
    end

    it 'keeps the children' do
      expect(group.children).to eq([spins])
    end
  end

  describe '#examples' do
    it 'returns the examples of its children' do
      group = described_class.new(description: 'when idle', children: [spins, stops])

      expect(group.examples).to eq([spins, stops])
    end

    it 'returns the examples of nested groups too, in order' do
      inner = described_class.new(description: 'and warm', children: [stops])
      outer = described_class.new(description: 'when idle', children: [spins, inner])

      expect(outer.examples).to eq([spins, stops])
    end
  end
end
