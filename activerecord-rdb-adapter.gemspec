# frozen_string_literal: true

Gem::Specification.new do |s|
  s.author = "REDSOFT"
  s.name = "activerecord-rdb-adapter"
  s.version = "6.1.1.beta1"
  s.summary = "ActiveRecord RedDatabase 3+ and Firebird 3+ Adapter"
  s.description = "ActiveRecord RedDatabase 3+ and Firebird 3+ Adapter for Rails 6+"

  s.required_ruby_version = ">= 2.7.0"

  s.licenses = "MIT"

  s.files = Dir["README.md", "lib/**/*"]
  s.require_paths = "lib"

  s.add_dependency "activerecord", "~> 6.1"
  s.add_dependency "rake"
end
