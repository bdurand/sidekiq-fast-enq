# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

Gem::Specification.new do |spec|
  spec.name          = "sidekiq_fast_enq"
  spec.version       = File.read(File.expand_path("../VERSION", __FILE__)).chomp
  spec.authors       = ["We Heart It", "Brian Durand"]
  spec.email         = ["dev@weheartit.com", "bbdurand@gmail.com"]
  spec.summary       = "More efficient scheduled job queue implementation for sidekiq"
  spec.description   = "More efficient scheduled job queue implementation for sidekiq to increase throughput in large installations."
  spec.homepage      = "https://github.com/weheartit/sidekiq_fast_enq"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency('sidekiq', '~>3.4')

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "timecop"
end
