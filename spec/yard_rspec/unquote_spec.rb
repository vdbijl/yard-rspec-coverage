# frozen_string_literal: true

RSpec.describe YardRspec::Unquote do
  describe '.call' do
    it 'removes single quotes around the text' do
      expect(described_class.call("'#spin'")).to eq('#spin')
    end

    it 'removes double quotes around the text' do
      expect(described_class.call('"#spin"')).to eq('#spin')
    end

    it 'keeps quotes inside the text' do
      expect(described_class.call(%q('#spin\'s "fast"'))).to eq(%q(#spin\'s "fast"))
    end

    it 'returns text without surrounding quotes as it is' do
      expect(described_class.call('Widget')).to eq('Widget')
    end
  end
end
