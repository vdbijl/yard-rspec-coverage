# frozen_string_literal: true

require 'tmpdir'
require 'yard_rspec/task_reports'

RSpec.describe YardRspec::TaskReports do
  let(:method_object) do
    instance_double(YARD::CodeObjects::MethodObject, path: 'Widget#spin', file: 'widget.rb',
                                                     line: 2)
  end

  describe '.rspec_coverage' do
    before {allow($stdout).to receive(:write)}

    context 'with an uncovered method' do
      before {allow(YardRspec::Coverage).to receive(:covered?).and_return(false)}

      it 'prints the coverage and lists the location and path of the method' do
        expect {described_class.rspec_coverage([method_object])}.to output(<<~TEXT).to_stdout
          RSpec coverage: 0/1 (0.00%)

          Methods without RSpec specs:
            widget.rb:2: Widget#spin
        TEXT
      end
    end

    context 'with several uncovered methods' do
      let(:other_method_object) do
        instance_double(YARD::CodeObjects::MethodObject, path: 'Gadget#tilt', file: 'gadget.rb',
                                                         line: 5)
      end

      before {allow(YardRspec::Coverage).to receive(:covered?).and_return(false)}

      it 'lists them sorted by path' do
        expect {described_class.rspec_coverage([method_object, other_method_object])}
          .to output(<<~TEXT).to_stdout
            RSpec coverage: 0/2 (0.00%)

            Methods without RSpec specs:
              gadget.rb:5: Gadget#tilt
              widget.rb:2: Widget#spin
          TEXT
      end
    end

    it 'returns 100 without methods' do
      expect(described_class.rspec_coverage([])).to eq(100.0)
    end

    # 57.0 / 100 * 100 is 56.99999999999999 in floating point, which would fail a minimum of 57.
    it 'returns an exact percentage exactly, such as 57 for 57 of 100' do
      allow(YardRspec::Coverage).to receive(:covered?) {|method| method != method_object}
      methods = Array.new(57) {method_object.dup} + Array.new(43) {method_object}

      expect(described_class.rspec_coverage(methods)).to eq(57.0)
    end

    it 'returns the unrounded percentage, so one miss in 20,000 stays below 100' do
      allow(YardRspec::Coverage).to receive(:covered?) {|method| method != method_object}
      methods = Array.new(19_999) {method_object.dup} << method_object

      expect(described_class.rspec_coverage(methods)).to be < 100.0
    end
  end

  describe '.rspec_coverage output' do
    it 'never prints 100.00% while a method is uncovered' do
      allow(YardRspec::Coverage).to receive(:covered?) {|method| method != method_object}
      methods = Array.new(99_999) {method_object.dup} << method_object

      expect {described_class.rspec_coverage(methods)}
        .to output(/\(99\.99%\)/).to_stdout
    end
  end

  describe '.yardoc_with_yardopts' do
    it 'returns a Yardoc that has the given files' do
      expect(described_class.yardoc_with_yardopts(['lib/**/*.rb']).files).to eq(['lib/**/*.rb'])
    end

    context 'when .yardopts lists files and an exclude' do
      around do |example|
        Dir.mktmpdir do |directory|
          File.write(File.join(directory, '.yardopts'), "--exclude lib/generated\napp/**/*.rb\n")
          Dir.chdir(directory) {example.run}
        end
      end

      it 'returns a Yardoc whose files replace the ones in .yardopts' do
        expect(described_class.yardoc_with_yardopts(['lib/**/*.rb']).files).to eq(['lib/**/*.rb'])
      end

      it 'returns a Yardoc that keeps the excludes of .yardopts' do
        expect(described_class.yardoc_with_yardopts(['lib/**/*.rb']).excluded)
          .to eq(['lib/generated'])
      end
    end
  end

  describe '.describe_problems' do
    it 'prints nothing without problems' do
      expect {described_class.describe_problems([])}.not_to output.to_stdout
    end

    it 'lists the problems' do
      expect {described_class.describe_problems(['a.rb:1: problem'])}.to output(<<~TEXT).to_stdout

        Describe blocks without a matching class or method:
          a.rb:1: problem
      TEXT
    end
  end
end
