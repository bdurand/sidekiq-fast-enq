# Breaks if not required. Sidekiq doesn't directly require in
# the load process.

require_relative "../lib/sidekiq-fast-enq"

require "timecop"
require "sidekiq/version"
require "celluloid" if Sidekiq::VERSION.to_i < 4
require "sidekiq/scheduled"
require "sidekiq/api"

RSpec.configure do |config|
  config.run_all_when_everything_filtered = true
  config.filter_run :focus

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = "random"

  Sidekiq.configure_server do |config|
    config.redis = {namespace: "sidekiq_fast_enq_test"}
  end

  options = (Sidekiq.respond_to?(:default_configuration) ? Sidekiq.default_configuration : Sidekiq.options)
  options[:scheduled_enq] = SidekiqFastEnq

  Sidekiq.logger.level = Logger::FATAL
end

class FastEnqTestWorker
  include Sidekiq::Worker

  def perform(arg)
  end
end
