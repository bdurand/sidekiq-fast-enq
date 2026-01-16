# Breaks if not required. Sidekiq doesn't directly require in
# the load process.

require_relative "../lib/sidekiq-fast-enq"

require "timecop"
require "sidekiq/version"
require "celluloid" if Sidekiq::VERSION.to_i < 4
require "sidekiq/scheduled"
require "sidekiq/api"

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.default_formatter = "doc" if config.files_to_run.one? || ENV["RSPEC_FORMATTER"] == "doc"
  config.order = :random
  Kernel.srand config.seed

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
