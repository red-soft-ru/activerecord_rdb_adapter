# frozen_string_literal: true

require "rake/testtask"

require_relative "test/config"
require_relative "test/support/config"

Rake::TestTask.new('rdb' => "rdb:env") do |t|
  t.libs << "test"
  t.test_files = FileList["test/cases/adapters/rdb/**/*_test.rb"]

  t.warning = true
  t.verbose = true
end

namespace :db do
  task :build do
    config = ARTest.config["connections"]["rdb"]
    %x( echo "CREATE DATABASE \
 'inet4://#{config["arunit"]["host"]}:#{config["arunit2"]["port"]}/#{config["arunit"]["database"]}' \
 USER '#{config["arunit"]["username"]}' \
 PASSWORD '#{config["arunit"]["password"]}' \
 PAGE_SIZE #{config["arunit"]["page_size"]} \
 DEFAULT CHARACTER SET #{config["arunit"]["charset"]} \
 COLLATION #{config["arunit"]["charset"]};" | \
 docker exec -i RedDatabase isql )

    %x( echo "CREATE DATABASE \
 'inet4://#{config["arunit2"]["host"]}:#{config["arunit2"]["port"]}/#{config["arunit2"]["database"]}' \
 USER '#{config["arunit2"]["username"]}' \
 PASSWORD '#{config["arunit2"]["password"]}' \
 PAGE_SIZE #{config["arunit2"]["page_size"]} \
 DEFAULT CHARACTER SET #{config["arunit2"]["charset"]} \
 COLLATION #{config["arunit2"]["charset"]};" | \
 docker exec -i RedDatabase isql )
  end

  task :drop do
    config = ARTest.config["connections"]["rdb"]
    %x( echo 'drop database;' | \
 docker exec -i RedDatabase isql \
 -user '#{config["arunit"]["username"]}' \
 -password '#{config["arunit"]["password"]}' \
 'inet4://#{config["arunit"]["host"]}:#{config["arunit"]["port"]}/#{config["arunit"]["database"]}' )

    %x( echo 'drop database;' | \
 docker exec -i RedDatabase isql \
 -user '#{config["arunit2"]["username"]}' \
 -password '#{config["arunit2"]["password"]}' \
 'inet4://#{config["arunit2"]["host"]}:#{config["arunit2"]["port"]}/#{config["arunit2"]["database"]}' )
  end

  task rebuild: [:drop, :build]
end
