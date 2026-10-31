# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'rake'
require 'tmpdir'

# Loaded once, because loading the rake file again resets its line coverage.
RAKE_TASKS_APPLICATION = Rake.with_application do
  load File.expand_path('../../lib/yard_rspec/rake_tasks.rb', __dir__)
end

RSpec.describe 'yard_rspec/rake_tasks', type: :task do
  around do |example|
    original_application = Rake.application
    Rake.application = Rake::Application.new
    example.run
  ensure
    Rake.application = original_application
  end

  # A new process, because this one has already loaded the plugin.
  it 'does not load the YARD handler, so other YARD runs (e.g. yard:coverage) are unaffected' do
    lib_dir = File.expand_path('../../lib', __dir__)
    script = "require 'yard_rspec/rake_tasks'; print defined?(YardRspec::DescribeHandler).inspect"
    output, _status = Open3.capture2('ruby', '-I', lib_dir, '-e', script)

    expect(output).to eq('nil')
  end

  # A new process, because this one has already loaded the plugin.
  it 'loads the YARD handler when yard:doc runs, since YARD ignores --plugin in-process' do
    lib_dir = File.expand_path('../../lib', __dir__)
    script = <<~RUBY
      require 'yard_rspec/rake_tasks'
      YARD::CLI::Yardoc.define_singleton_method(:run) {|*_arguments| nil}
      Rake::Task['yard:doc'].invoke
      print defined?(YardRspec::DescribeHandler).inspect
    RUBY
    output, _status = Open3.capture2('ruby', '-I', lib_dir, '-e', script)

    expect(output).to eq('"constant"')
  end

  context 'when required' do
    around do |example|
      Rake.with_application(RAKE_TASKS_APPLICATION) {example.run}
    ensure
      RAKE_TASKS_APPLICATION.tasks.each(&:reenable)
    end

    it 'defines the yard:doc and yard:rspec_coverage tasks' do
      expect(Rake::Task.tasks.map(&:name)).to include('yard:doc', 'yard:rspec_coverage')
    end

    it 'runs yard doc in-process on the lib and spec files' do
      expect(YARD::CLI::Yardoc).to receive(:run)
                               .with('{lib,spec}/**/*.rb')

      Rake.application['yard:doc'].invoke
    end

    context 'when yard:rspec_coverage parses a describe of a missing method' do
      let(:dir) {Dir.mktmpdir}

      after do
        FileUtils.remove_entry(dir)
        YardRspec::Config.files = nil
      end

      before do
        File.write(File.join(dir, 'widget.rb'), <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
        File.write(File.join(dir, 'widget_spec.rb'), <<~RUBY)
          describe Widget, '#spin' do
            it 'spins' do; end
          end
          describe Widget, '#wobble' do
            it 'wobbles' do; end
          end
        RUBY
        YardRspec::Config.files = ["#{dir}/*.rb"]
      end

      it 'lists the describe problem without failing' do
        expect {Rake.application['yard:rspec_coverage'].invoke}.to output(<<~TEXT).to_stdout
          RSpec coverage: 1/1 (100.00%)

          Describe blocks without a matching class or method:
            #{dir}/widget_spec.rb:4: could not find method '#wobble' on 'Widget'
        TEXT
      end
    end

    context 'when yard:rspec_coverage finds a method with only pending examples' do
      let(:dir) {Dir.mktmpdir}

      after do
        FileUtils.remove_entry(dir)
        YardRspec::Config.files = nil
        YardRspec::Config.minimum_rspec_coverage = nil
      end

      before do
        File.write(File.join(dir, 'widget.rb'), <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
        File.write(File.join(dir, 'widget_spec.rb'), <<~RUBY)
          describe Widget, '#spin' do
            xit 'spins' do; end
          end
        RUBY
        YardRspec::Config.files = ["#{dir}/*.rb"]
        YardRspec::Config.minimum_rspec_coverage = 0.0
      end

      it 'lists the method as without specs' do
        expect {Rake.application['yard:rspec_coverage'].invoke}.to output(<<~TEXT).to_stdout
          RSpec coverage: 0/1 (0.00%)

          Methods without RSpec specs:
            #{dir}/widget.rb:2: Widget#spin
        TEXT
      end
    end

    context 'when yard:rspec_coverage finds coverage below the minimum' do
      let(:dir) {Dir.mktmpdir}

      after do
        FileUtils.remove_entry(dir)
        YardRspec::Config.files = nil
      end

      before do
        File.write(File.join(dir, 'widget.rb'), <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
        YardRspec::Config.files = ["#{dir}/*.rb"]
      end

      it 'warns that the coverage is too low' do
        expect {Rake.application['yard:rspec_coverage'].invoke}
          .to output("\nRSpec coverage too low: 0.00% (minimum is 100.00%)\n").to_stderr
          .and output.to_stdout
          .and raise_error(SystemExit)
      end

      it 'exits with status 1' do
        expect {Rake.application['yard:rspec_coverage'].invoke}
          .to raise_error(an_object_having_attributes(status: 1))
          .and output.to_stdout
          .and output.to_stderr
      end
    end

    # YARD reads .yardopts from the current directory.
    context 'when yard:rspec_coverage runs in a project whose .yardopts excludes a file' do
      let(:dir) {Dir.mktmpdir}

      around do |example|
        Dir.chdir(dir) {example.run}
      ensure
        FileUtils.remove_entry(dir)
        YardRspec::Config.files = nil
        YardRspec::Config.minimum_rspec_coverage = nil
      end

      before do
        File.write('.yardopts', "--exclude generated.rb\n")
        File.write('generated.rb', <<~RUBY)
          class Generated
            def reduce; end
          end
        RUBY
        File.write('widget.rb', <<~RUBY)
          class Widget
            def spin; end
          end
        RUBY
        File.write('widget_spec.rb', <<~RUBY)
          describe Widget, '#spin' do
            it 'spins' do; end
          end
        RUBY
        YardRspec::Config.files = ['*.rb']
        # Below the minimum the task exits, which silently stops RSpec.
        YardRspec::Config.minimum_rspec_coverage = 0.0
      end

      it 'does not count the methods of the excluded file' do
        expect {Rake.application['yard:rspec_coverage'].invoke}.to output(<<~TEXT).to_stdout
          RSpec coverage: 1/1 (100.00%)
        TEXT
      end
    end
  end
end
