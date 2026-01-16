Sidekiq Fast Enqueuing

[![Continuous Integration](https://github.com/bdurand/sidekiq-fast-enq/actions/workflows/continuous_integration.yml/badge.svg)](https://github.com/bdurand/sidekiq-fast-enq/actions/workflows/continuous_integration.yml)
[![Ruby Style Guide](https://img.shields.io/badge/code_style-standard-brightgreen.svg)](https://github.com/testdouble/standard)
[![Gem Version](https://badge.fury.io/rb/sidekiq-fast-enq.svg)](https://badge.fury.io/rb/sidekiq-fast-enq)

> [!NOTE]
> This gem is no longer needed starting with Sidekiq version 6.3. That version addressed the performance issues with the scheduled and retry queues that this gem was created to solve.

This gem provides a much more efficien implementation for checking the Sidekiq scheduled and retry queues. This can provide a significant performance boost for large sidekiq implementations that utilize many processes. It can also reduce load on the redis server.

### TL;DR

The default implementation included with the sidekiq gem works very well when there are only a few processes running. However, with a large number of processes it is vulnerable to race conditions when there are a lot of scheduled jobs and a lot of sidekiq processes. Each process will maintain a thread that checks the scheduled and retry job queues. These queues are kept in sorted sets with the timestamp to run the jobs as the sorting key. Each process will run a redis command to sort the set and return the first element whose key is less than the current timestamp. It then removes the job from the scheduled queue and adds it to the appropriate job queue. The problem is that if there are a lot schedule jobs, the set sorting operation can take a not insignificant amount of time. If there are lot of processes this will lead to a lot of race conditions where for each job run the large set will be sorted many times.

This gem re-implements the same logic, but using a server side Lua script so that the sorting and popping from the list become an atomic operation eliminating the race conditions as well as using more efficient redis commands.

On a single sidekiq process this implementation is about twice as fast. With 64 processes it's about nine times as fast and puts significantly less load on redis.

This plugin does not alter any sidekiq internal code or data structures.

### Usage

In your sidekiq configuration you need to set the `:scheduled_enq` option to `SidekiqFastEnq` (only available in sidekiq 3.4.0 and later). You might also want to hard code a value for the `:poll_interval_average` option as well. If this option is not set the polling interval for checking the scheduled queues is based on the number of processes in an effort to reduce the effects of the race condition. It is not needed with this code and scheduled jobs will be enqueued closer to their scheduled time without it.

```ruby
Sidekiq.default_configuration[:scheduled_enq] = SidekiqFastEnq
Sidekiq.default_configuration[:poll_interval_average] = 30
```

For Sidekiq versions prior to version 7:

```ruby
Sidekiq.options[:scheduled_enq] = SidekiqFastEnq
Sidekiq.options[:poll_interval_average] = 30
```


### Redis requirement

Redis server 2.6 or greater is required for this code.

You can run one locally with docker:

```bash
docker run --rm -p 6379:6379 redis
```

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'sidekiq-fast-enq'
```

And then execute:
```bash
$ bundle
```

Or install it yourself as:
```bash
$ gem install sidekiq-fast-enq
```

## Contributing

Fork the repository and open a pull request on GitHub.

Please use the [standardrb](https://github.com/testdouble/standard) syntax and lint your code with `standardrb --fix` before submitting.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
