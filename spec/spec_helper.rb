# Breaks if not required. Sidekiq doesn't directly require in
# the load process.

sidekiq_version = Array(ENV["SIDEKIQ_VERSION"] || "~>3.0")
gem 'sidekiq', *sidekiq_version

require 'celluloid'

require File.expand_path('../../lib/sidekiq-fast-enq', __FILE__)
require 'timecop'
require 'sidekiq/api'

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = 'random'
  
  Sidekiq.configure_server do |config|
    config.redis = {:namespace => "sidekiq_fast_enq_test"}
  end
  Sidekiq.options[:scheduled_enq] = SidekiqFastEnq
end

class FastEnqTestWorker
  include Sidekiq::Worker
  
  def perform(arg)
  end
end
