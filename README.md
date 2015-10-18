This gem provides a better implementation for checking the Sidekiq scheduled and retry queues for large sidekiq implementations.

The default implementation included with the sidekiq gem is vulnerable to race conditions when there are a lot of scheduled jobs and a lot of sidekiq processes. Each process will maintain a thread that checks the scheduled job queues. The scheduled jobs are kept in a sorted set with the timestamp to run it as the sorting key. Each process will run a redis command to sort the set and return the first element whose key is less than the curren timestamp. It then removes the job from the scheduled queue and adds it to the regular run queue. The problem is that if there are a lot schedule jobs, the set sorting operation can take a not insignificant amount of time. If there are lot of processes this will lead to a lot of race conditions where for each job run the large set will be sorted many times.

This gem re-implements the same logic, but using a server side Lua script so that the sorting and popping from the list become an atomic operation eliminating the race conditions and also using some more efficient redis commands.

### Usage

In your sidekiq configuration you need to set the `:scheduled_enq` option to `SidekiqFastEnq` (only available in sidekiq 3.4.0 and later)

```ruby
Sidekiq.options[:scheduled_enq] = SidekiqFastEnq
```

Note: you must be using Redis Server 2.6.0 or later with this gem.
