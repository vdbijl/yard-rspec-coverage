# frozen_string_literal: true

RSpec.describe YardRspec::ParsedDescribe::Entry do
  describe '.new' do
    subject(:entry) do
      described_class.new(YardRspec::MethodDescription.parse('#spin'),
                          [spins], 'widget_spec.rb:2')
    end

    let(:spins) {YardRspec::Example.new(description: 'spins', code: '')}

    it 'keeps the method description' do
      expect(entry.description.to_s).to eq('#spin')
    end

    it 'keeps the examples' do
      expect(entry.examples).to eq([spins])
    end

    it 'keeps the location of the describe of the method' do
      expect(entry.location).to eq('widget_spec.rb:2')
    end
  end
end
