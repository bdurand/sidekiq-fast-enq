require 'sidekiq/scheduled'

module Sidekiq
  module Scheduled
    # Implementation of the Sidekiq::Scheduled::Enq class that uses a server side Lua script
    # to atomically get the next scheduled job to run and then pops it from the list. This
    # works much better in large sidekiq deployments with many processes because it eliminates
    # race conditions checking the scheduled queues.
    class FastEnq
      def initialize
        @script = lua_script
        Sidekiq.redis do |conn|
          @script_sha_1 = conn.script(:load, @script)
        end
      end
      
      def enqueue_jobs(now = Time.now.to_f.to_s, sorted_sets = Sidekiq::Scheduled::SETS)
        # A job's "score" in Redis is the time at which it should be processed.
        # Just check Redis for the set of jobs with a timestamp before now.
        Sidekiq.redis do |conn|
          namespace = conn.namespace if conn.respond_to?(:namespace)
          sorted_sets.each do |sorted_set|
            sorted_set = "#{namespace}:#{sorted_set}" if namespace
            # Get the next item in the queue if it's score (time to execute) is <= now.
            # We need to go through the list one at a time to reduce the risk of something
            # going wrong between the time jobs are popped from the scheduled queue and when
            # they are pushed onto a work queue and losing the jobs.
            while job = pop_job(conn, sorted_set, now) do
              Sidekiq::Client.push(Sidekiq.load_json(job))
              Sidekiq::Logging.logger.debug("enqueued #{sorted_set}: #{job}") if Sidekiq::Logging.logger.debug?
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
      def lua_script
        <<-LUA
        local sorted_set = ARGV[1]
        local now = tonumber(ARGV[2])
        local ready_cache = sorted_set .. '.cache'
        
        while true do
          -- Check a cached list of jobs that are ready to execute
          local job = redis.call('lpop', ready_cache)
          if not job then
            -- If no jobs in the cache then get the next 100 jobs ready to be executed
            local ready_jobs = redis.call('zrangebyscore', sorted_set, '-inf', now, 'LIMIT', 0, 100)
            if #ready_jobs == 1 then
              job = ready_jobs[1]
            elseif #ready_jobs > 1 then
              -- If more than one job is ready, throw them in the cache which is faster to access than the sorted set
              redis.call('rpush', ready_cache, unpack(ready_jobs))
              -- Set an expiration on the cache since it's just a cache. The sorted set is still the canonical list.
              redis.call('expire', ready_cache, 10)
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
  end
end