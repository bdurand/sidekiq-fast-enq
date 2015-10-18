This gem provides a much more efficien implementation for checking the Sidekiq scheduled and retry queues. This can provide a significant performance boost for large sidekiq implementations that utilize many processes. It can also reduce load on the redis server.

### TL;DR

The default implementation included with the sidekiq gem works very well when there are only a few processes running. However, with a large number of processes it is vulnerable to race conditions when there are a lot of scheduled jobs and a lot of sidekiq processes. Each process will maintain a thread that checks the scheduled and retry job queues. These queues are kept in sorted sets with the timestamp to run the jobs as the sorting key. Each process will run a redis command to sort the set and return the first element whose key is less than the current timestamp. It then removes the job from the scheduled queue and adds it to the appropriate job queue. The problem is that if there are a lot schedule jobs, the set sorting operation can take a not insignificant amount of time. If there are lot of processes this will lead to a lot of race conditions where for each job run the large set will be sorted many times.

This gem re-implements the same logic, but using a server side Lua script so that the sorting and popping from the list become an atomic operation eliminating the race conditions as well as using more efficient redis commands.

On a single sidekiq process this implementation is about twice as fast. With 64 processes it's about nine times as fast and puts significantly less load on redis.

### Usage

In your sidekiq configuration you need to set the `:scheduled_enq` option to `SidekiqFastEnq` (only available in sidekiq 3.4.0 and later)

```ruby
Sidekiq.options[:scheduled_enq] = SidekiqFastEnq
```

Note: this gem utilizes server side Lua scripting so you must be using Redis Server 2.6.0 or later.
