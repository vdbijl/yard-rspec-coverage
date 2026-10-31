# frozen_string_literal: true

YARD::CLI::Stats.class_eval do
  # Prints the RSpec specs row. Leaves @total/@undocumented alone, so "% documented" is unaffected.
  def stats_for_rspec
    public_lib_methods = YardRspec::Coverage.countable_methods

    total   = public_lib_methods.size
    covered = public_lib_methods.count {|method| YardRspec::Coverage.covered?(method)}

    log.puts "RSpec specs: #{rspec_specs_data(covered, total - covered)}"
  end

  private

  # @return [String]
  def rspec_specs_data(covered, uncovered)
    if uncovered.positive?
      format('%<covered>5d (%<uncovered>5d without specs)', covered:, uncovered:)
    else
      format('%<covered>5d', covered:)
    end
  end
end
