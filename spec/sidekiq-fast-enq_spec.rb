require "spec_helper"

describe SidekiqFastEnq do
  let(:scheduled_set) { Sidekiq::ScheduledSet.new }
  let(:retry_set) { Sidekiq::RetrySet.new }
  let(:default_queue) { Sidekiq::Queue.new }

  before :each do
    scheduled_set.clear
    retry_set.clear
    default_queue.clear
  end

  it "should return without doing anything if there are no scheduled jobs" do
    SidekiqFastEnq.new.enqueue_jobs
    expect(scheduled_set.size).to eq(0)
    expect(retry_set.size).to eq(0)
    expect(default_queue.size).to eq(0)
  end

  it "should enqueue a single elligible job from the scheduled jobs queue" do
    Timecop.travel(Time.now - 3600) { FastEnqTestWorker.perform_in(60, "one") }
    SidekiqFastEnq.new.enqueue_jobs
    expect(scheduled_set.size).to eq(0)
    expect(retry_set.size).to eq(0)
    expect(default_queue.size).to eq(1)
  end

  it "should enqueue all elligible jobs from the scheduled jobs queue" do
    Timecop.travel(Time.now - 3600) { FastEnqTestWorker.perform_in(60, "one") }
    Timecop.travel(Time.now - 3600) { FastEnqTestWorker.perform_in(900, "two") }
    FastEnqTestWorker.perform_in(10, "three")
    SidekiqFastEnq.new.enqueue_jobs
    expect(scheduled_set.size).to eq(1)
    expect(retry_set.size).to eq(0)
    expect(default_queue.size).to eq(2)
  end

  it "should enqueue all elligible jobs from the scheduled jobs queue when there are a lot of them" do
    Timecop.travel(Time.now - 3600) do
      200.times do
        FastEnqTestWorker.perform_in(60, "one")
      end
    end
    FastEnqTestWorker.perform_in(10, "three")
    SidekiqFastEnq.new.enqueue_jobs
    expect(scheduled_set.size).to eq(1)
    expect(retry_set.size).to eq(0)
    expect(default_queue.size).to eq(200)
  end
end
