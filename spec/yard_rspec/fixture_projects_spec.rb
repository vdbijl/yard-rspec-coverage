# frozen_string_literal: true

require 'open3'
require 'tmpdir'

# Runs the task in a new process inside each project in spec/fixtures, as a consumer would. This
# checks assumptions about YARD itself, such as how it reads .yardopts, which stubs cannot.
RSpec.describe 'yard:rspec_coverage in a fixture project', type: :task do
  # @return [(String, String, Integer)] The stdout, stderr and exit status of the task.
  def run_task(project)
    lib_dir = File.expand_path('../../lib', __dir__)
    project_dir = File.expand_path("../fixtures/#{project}", __dir__)
    stdout, stderr, status =
      Open3.capture3('rake', '-I', lib_dir, 'yard:rspec_coverage', chdir: project_dir)
    [stdout, stderr, status.exitstatus]
  end

  # Runs the yard executable with the plugin, as `yard doc --plugin rspec-coverage` does for a user.
  def run_yard(project, *args)
    lib_dir = File.expand_path('../../lib', __dir__)
    project_dir = File.expand_path("../fixtures/#{project}", __dir__)
    # Added to RUBYLIB, not replacing it: tools such as mutaruby load themselves through it.
    rubylib = [lib_dir, ENV.fetch('RUBYLIB', nil)].compact.join(File::PATH_SEPARATOR)
    stdout, _stderr, status =
      Open3.capture3({ 'RUBYLIB' => rubylib }, 'yard', *args, '--plugin', 'rspec-coverage',
                     chdir: project_dir)
    [stdout, status.exitstatus]
  end

  context 'when .yardopts lists files outside Config.files and excludes a file' do
    it 'counts only the methods in Config.files that are not excluded' do
      expect(run_task('yardopts_files')).to eq(["RSpec coverage: 1/1 (100.00%)\n", '', 0])
    end
  end

  context 'when specs describe methods of a superclass and of mixins' do
    it 'counts the methods of the superclass, the included and the extended module as covered' do
      expect(run_task('mixins')).to eq(["RSpec coverage: 5/5 (100.00%)\n", '', 0])
    end
  end

  context 'when coverage is below the minimum' do
    it 'lists the uncovered methods and describe problems, and fails' do
      expect(run_task('low_coverage')).to eq([<<~TEXT, <<~ERROR, 1])
        RSpec coverage: 1/3 (33.33%)

        Methods without RSpec specs:
          lib/widget.rb:4: Widget#tilt
          lib/widget.rb:6: Widget#wobble

        Describe blocks without a matching class or method:
          spec/widget_spec.rb:13: could not find method '#spinn' on 'Widget'
          spec/widget_spec.rb:19: could not resolve class 'Gadget'
      TEXT

        RSpec coverage too low: 33.33% (minimum is 50.00%)
      ERROR
    end
  end

  context 'when coverage is below 100% but meets a lower minimum' do
    it 'lists the uncovered method and succeeds' do
      expect(run_task('lenient_minimum')).to eq([<<~TEXT, '', 0])
        RSpec coverage: 1/2 (50.00%)

        Methods without RSpec specs:
          lib/widget.rb:7: Widget#tilt
      TEXT
    end
  end

  context 'when the yard executable loads the plugin' do
    it 'adds the RSpec specs row to yard stats' do
      stdout, status = run_yard('lenient_minimum', 'stats', '--no-save', 'lib', 'spec')
      expect([stdout[/^RSpec specs:.*$/], status])
        .to eq(['RSpec specs:     1 (    1 without specs)', 0])
    end

    context 'with yard doc' do
      let(:output) {Dir.mktmpdir}
      let(:status) do
        run_yard('lenient_minimum', 'doc', '-q', '--no-save', '-o', output, 'lib', 'spec').last
      end

      before {status} # Runs yard doc.

      after {FileUtils.remove_entry(output)}

      it 'succeeds' do
        expect(status).to eq(0)
      end

      it 'puts the examples and the no specs label in the page of the class' do
        expect(File.read("#{output}/Widget.html"))
          .to include('RSpec Examples (1)', 'spins', 'no specs')
      end
    end
  end
end
