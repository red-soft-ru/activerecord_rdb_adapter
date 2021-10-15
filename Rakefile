# frozen_string_literal: true

require 'rake'
require 'rake/testtask'

require_relative "test/config"
require_relative "test/support/config"

Rake::TestTask.new do |t|
  t.libs << "test"
  t.test_files = FileList["test/**/*_test.rb"]

  t.warning = true
  t.verbose = true
end

task default: [:test]

namespace :db do
  desc "Build the RedDatabase test databases"
  task :build do
    config = ARTest.config["default"]
    %x( echo "CREATE DATABASE \
 'inet4://#{config["host"]}:#{config["port"]}/#{config["database"]}' \
 USER '#{config["username"]}' \
 PASSWORD '#{config["password"]}' \
 PAGE_SIZE #{config["page_size"]} \
 DEFAULT CHARACTER SET #{config["charset"]} \
 COLLATION #{config["charset"]};" | \
 docker exec -i RedDatabase isql )
  end

  desc "Drop the RedDatabase test databases"
  task :drop do
    config = ARTest.config["default"]
    %x( echo 'drop database;' | \
 docker exec -i RedDatabase isql \
 -user '#{config["username"]}' \
 -password '#{config["password"]}' \
 'inet4://#{config["host"]}:#{config["port"]}/#{config["database"]}' )
  end

  desc "Rebuild the RedDatabase test databases"
  task rebuild: [:drop, :build]
end
