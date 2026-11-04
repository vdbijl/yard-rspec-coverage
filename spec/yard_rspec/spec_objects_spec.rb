# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

RSpec.describe YardRspec::SpecObjects do
  describe '.remove' do
    # Removed after a parse of a file list, the way `yard doc` and `yard stats` parse.
    context 'when spec files define classes, modules and methods outside describe blocks' do
      let(:dir) {Dir.mktmpdir}

      after {FileUtils.remove_entry(dir)}

      before do
        FileUtils.mkdir_p(File.join(dir, 'lib'))
        FileUtils.mkdir_p(File.join(dir, 'spec/support'))
        File.write(File.join(dir, 'lib/widget.rb'), <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
        File.write(File.join(dir, 'spec/support/helpers.rb'), <<~RUBY)
          module SpecHelpers
            def build_widget; end
          end

          def top_level_helper; end
        RUBY
        File.write(File.join(dir, 'spec/widget_spec.rb'), <<~RUBY)
          class FakeMotor
            def run; end
          end

          class Widget
            def spec_only_helper; end
          end

          RSpec.describe Widget, '#spin' do
            it 'spins' do; end
          end
        RUBY
        YARD.parse(["#{dir}/lib/**/*.rb", "#{dir}/spec/**/*.rb"])
      end

      it 'leaves only the objects defined outside the spec files' do
        expect(YARD::Registry.all.map(&:path).sort).to eq(['Widget', 'Widget#spin'])
      end

      it 'removes the spec files from the files of a class that a spec reopens' do
        expect(YARD::Registry.at('Widget').files).to eq([["#{dir}/lib/widget.rb", 1]])
      end

      it 'removes the objects from their namespace too' do
        expect(YARD::Registry.root.children.map(&:path)).to eq(['Widget'])
      end

      it 'keeps the examples of the described methods' do
        expect(YARD::Registry.at('Widget#spin')[:rspec_examples])
          .to eq([{ description: 'spins', code: '' }])
      end
    end

    # YARD knows the namespace of the gem only as a proxy, which has no children.
    context 'when a spec file reopens a class of another gem' do
      let(:dir) {Dir.mktmpdir}

      after {FileUtils.remove_entry(dir)}

      before do
        FileUtils.mkdir_p(File.join(dir, 'spec/support'))
        File.write(File.join(dir, 'spec/support/middleware.rb'), <<~RUBY)
          class Rack::Static::Middleware
            def call; end
          end
        RUBY
      end

      it 'removes the class and its methods' do
        YARD.parse(["#{dir}/spec/**/*.rb"])

        expect(YARD::Registry.all.map(&:path)).to eq([])
      end
    end
  end
end
