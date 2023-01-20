# ActiveRecord RedDatabase Adapter

An ActiveRecord adapter for RDBMS [RedDatabase 3](https://reddatabase.ru/) and [Firebird 3](https://firebirdsql.org).

This is a reworked version of [activerecord-fb-adapter](https://github.com/rowland/activerecord-fb-adapter).
Currently supports Rails 5.2 and 6.1. Use corresponding branch for the each version (5.2-stable or 6-1-stable).

GUI Database Editor for RedDatabase/Firebird: [RedExpert](https://reddatabase.ru/downloads/redexpert/)

## How to

Put in your gemfile

```ruby
gem "firebird", :git => "https://github.com/red-soft-ru/ruby-fb.git", :branch => "master"
gem "activerecord-rdb-adapter", :git => "https://github.com/red-soft-ru/activerecord_rdb_adapter.git", :branch => "6-1-stable"
```

Create a `database.yml` in your project:

```yml
default: &default
  adapter: rdb
  host: "<%= ENV.fetch("DB_HOST") { '0.0.0.0' } %>"
  port: "<%= ENV.fetch("DB_PORT") { 3050 } %>"
  database: "<%= ENV.fetch("DB_DATABASE") { '/db/rails.fdb' } %>"
  username: "<%= ENV.fetch("DB_USERNAME") { 'SYSDBA' } %>"
  password: "<%= ENV.fetch("DB_PASSWORD") { 'masterkey' } %>"
  encoding: "<%= ENV.fetch("DB_ENCODING") { 'utf-8' } %>"
  charset: "<%= ENV.fetch("DB_CHARSET") { 'utf8' } %>"
  collation: "<%= ENV.fetch("DB_COLLATION") { 'unicode_ci_ai' } %>"

development:
  <<: *default

production:
  <<: *default
  pool: "<%= ENV.fetch("RAILS_MAX_THREADS") { 50 } %>"

test:
  <<: *default
  database: "<%= ENV.fetch("DB_DATABASE") { '/db/rails-test.fdb' } %>"
  page_size: 16384
```
Run `bundle install`

## License
It is free software, and may be redistributed under the terms specified in the MIT-LICENSE file.