# frozen_string_literal: true

RSpec.describe YardRspec::Example do
  subject(:example) {described_class.new(description: 'spins', code: 'Widget.new.spin')}

  describe '.new' do
    it 'keeps the description' do
      expect(example.description).to eq('spins')
    end

    it 'keeps the code' do
      expect(example.code).to eq('Widget.new.spin')
    end
  end

  describe '#pending?' do
    context 'when not given as pending' do
      it 'returns false' do
        expect(example.pending?).to be(false)
      end
    end

    context 'when given as pending' do
      subject(:example) {described_class.new(description: 'spins', code: '', pending: true)}

      it 'returns true' do
        expect(example.pending?).to be(true)
      end
    end
  end

  describe '#examples' do
    it 'returns itself, so that an example and a group can be asked alike' do
      expect(example.examples).to eq([example])
    end
  end
end
