# frozen_string_literal: true

require 'sidekiq'

# Implementation of the Sidekiq::Scheduled::Enq class that uses a server side Lua script
# to atomically get the next scheduled job to run and then pops it from the list. This
# works much better in large sidekiq deployments with many processes because it eliminates
# race conditions checking the scheduled queues.
class SidekiqFastEnq
  DEFAULT_BATCH_SIZE = 1000

  def initialize(batch_size = nil)
    batch_size ||= (Sidekiq.options[:fast_enq_batch_size] || DEFAULT_BATCH_SIZE)
    @script = lua_script(batch_size)
    Sidekiq.redis do |conn|
      @script_sha_1 = conn.script(:load, @script)
    end
  end

  def enqueue_jobs(now = Time.now.to_f.to_s, sorted_sets = nil)
    sorted_sets ||= Sidekiq::Scheduled::SETS
    logger = Sidekiq.logger

    # A job's "score" in Redis is the time at which it should be processed.
    # Just check Redis for the set of jobs with a timestamp before now.
    Sidekiq.redis do |conn|
      namespace = conn.namespace if conn.respond_to?(:namespace)
      sorted_sets.each do |sorted_set|
        redis_set = (namespace ? "#{namespace}:#{sorted_set}" : sorted_set)
        jobs_count = 0
        start_time = Time.now
        pop_time = 0.0
        enqueue_time = 0.0

        # Get the next item in the queue if it's score (time to execute) is <= now.
        # We need to go through the list one at a time to reduce the risk of something
        # going wrong between the time jobs are popped from the scheduled queue and when
        # they are pushed onto a work queue and losing the jobs.
        loop do
          t = Time.now
          job = pop_job(conn, redis_set, now)
          pop_time += (Time.now - t)
          break if job.nil?
          t = Time.now
          Sidekiq::Client.push(Sidekiq.load_json(job))
          enqueue_time += (Time.now - t)
          jobs_count += 1
          logger.debug("enqueued #{sorted_set}: #{job}") if logger && logger.debug?
        end

        if jobs_count > 0 && logger && logger.info?
          loop_time = Time.now - start_time
          logger.info("SidekiqFastEnq enqueued #{jobs_count} from #{sorted_set} in #{loop_time.round(3)}s (pop: #{pop_time.round(3)}s; enqueue: #{enqueue_time.round(3)}s)")
        end
      end
    end
  end

  private

  # Invoke a Lua script on the server to pop the next job from a sorted set that should have
  # been run before "now".
  def pop_job(conn, sorted_set, now)
    eval_script(conn, @script, @script_sha_1, [sorted_set, now])
  end

  # Evaluate and execute a Lua script on the redis server.
  def eval_script(conn, script, sha1, argv=[])
    begin
      conn.evalsha(sha1, [], argv)
    rescue Redis::CommandError => e
      if e.message.include?('NOSCRIPT'.freeze)
        t = Time.now
        sha1 = conn.script(:load, script)
        Sidekiq::Logging.logger.info("loaded script #{sha1} in #{Time.now - t}s")
        retry
      else
        raise e
      end
    end
  end

  # Lua script that will atomically get the next element from the sorted set of scheduled jobs
  # and pop it from the list.
  def lua_script(batch_size)
    batch_size = batch_size.to_i
    batch_size = DEFAULT_BATCH_SIZE if batch_size <= 0
    <<-LUA
    local sorted_set = ARGV[1]
    local now = tonumber(ARGV[2])
    local ready_cache = sorted_set .. '.cache'

    while true do
      -- Check a cached list of jobs that are ready to execute
      local job = redis.call('lpop', ready_cache)
      if not job then
        -- If no jobs in the cache then get the next 100 jobs ready to be executed
        local ready_jobs = redis.call('zrangebyscore', sorted_set, '-inf', now, 'LIMIT', 0, #{batch_size})
        if #ready_jobs == 1 then
          job = ready_jobs[1]
        elseif #ready_jobs > 1 then
          -- If more than one job is ready, throw them in the cache which is faster to access than the sorted set
          redis.call('rpush', ready_cache, unpack(ready_jobs))
          -- Set an expiration on the cache since it's just a cache. The sorted set is still the canonical list.
          redis.call('expire', ready_cache, 60)
          job = redis.call('lpop', ready_cache)
        end
      end

      if job then
        -- Verify that the job was still in the sorted set when we remove. Could happen if
        -- another sidekiq process is still using the standard Enq mechanism.
        local removed = redis.call('zrem', sorted_set, job)
        if removed > 0 then
          return job
        end
      else
        return nil
      end
    end
    LUA
  end
end
