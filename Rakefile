require "bundler/gem_tasks"

desc 'Default: run unit tests.'
task :default => :test

desc 'RVM likes to call it tests'
task :tests => :test

begin
  require 'rspec'
  require 'rspec/core/rake_task'
  desc 'Run the unit tests'
  RSpec::Core::RakeTask.new(:test)
rescue LoadError
  task :test do
    STDERR.puts "You must have rspec 2.0 installed to run the tests"
  end
end

task :load_test, [:jobs_size, :workers, :fast] do |t, args|
  require 'celluloid'
  require File.expand_path('../lib/sidekiq-fast-enq', __FILE__)
  
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
