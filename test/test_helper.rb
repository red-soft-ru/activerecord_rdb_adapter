# frozen_string_literal: true

require "bundler/setup"
Bundler.require(:default, :development)

require "config"

require "rails"
require "active_support"
require "active_support/testing/autorun"
require "active_support/testing/method_call_assertions"
require "active_support/testing/stream"
require "active_record"
require "active_record/fixtures"

require "test_case"
require "support/config"

ActiveRecord::Base.logger = ActiveSupport::Logger.new("debug.log", 0, 100 * 1024 * 1024)

def load_schema
  # silence verbose schema loading
  original_stdout = $stdout
  $stdout = StringIO.new

  ActiveRecord::Base.establish_connection(ARTest.config["default"])

  adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
  adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

  load adapter_specific_schema_file

  ActiveRecord::FixtureSet.reset_cache
ensure
  $stdout = original_stdout
end

load_schema
