RSpec.describe Widget do
  describe '#spin' do
    it 'spins' do
      Widget.new.spin
    end
  end

  describe '.count' do
    it 'counts' do
      Widget.count
    end
  end

  describe '#start' do
    it 'starts' do
      Widget.new.start
    end
  end

  describe '#build' do
    it 'builds' do
      Widget.build
    end
  end

  context 'when wobbly' do
    describe '#wobble' do
      it 'wobbles' do
        Widget.new.wobble
      end
    end
  end
end
