begin
  require "bundler/setup"
rescue LoadError
  puts "You must `gem install bundler` and `bundle install` to run rake tasks"
end

require "yard"
YARD::Rake::YardocTask.new(:yard)

require "bundler/gem_tasks"

task :release do
  unless `git rev-parse --abbrev-ref HEAD`.chomp == "main"
    warn "Gem can only be released from the main branch"
    exit 1
  end
end

require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "run the specs using appraisal"
task :appraisals do
  exec "bundle exec appraisal rake spec"
end

namespace :appraisals do
  desc "install all the appraisal gemspecs"
  task :install do
    exec "bundle exec appraisal install"
  end
end

require "standard/rake"

task :load_test, [:jobs_size, :workers, :fast] do |t, args|
  require 'celluloid'
  require File.expand_path('../lib/sidekiq-fast-enq', __FILE__)
  require 'sidekiq/scheduled'
  require 'sidekiq/api'

  class FastEnqLoadTestWorker
    include Sidekiq::Worker
    def perform()
    end
  end

  jobs_size = args[:jobs_size].to_i
  workers_size = args[:workers].to_i
  klass = (args[:fast] == 'fast' ? SidekiqFastEnq : Sidekiq::Scheduled::Enq)

  Sidekiq.configure_server do |config|
    config.redis = {:namespace => "sidekiq_fast_enq_load_test"}
  end

  Sidekiq::ScheduledSet.new.clear
  jobs_size.times do
    FastEnqLoadTestWorker.perform_in(rand)
  end

  t = Time.now
  workers_size.times do
    fork do
      klass.new.enqueue_jobs
    end
  end

  workers_size.times do
    Process.wait
  end

  puts "Enqueued #{jobs_size} jobs in #{Time.now - t} seconds"
end
