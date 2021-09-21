# frozen_string_literal: true

require "config"

require "stringio"

require "active_record"
require "active_record/fixtures"
require "active_support/dependencies"
require "active_support/logger"
require "active_support/core_ext/kernel/singleton_class"

require "support/config"
require "support/connection"

require 'cases/helper'

# TODO: Move all these random hacks into the ARTest namespace and into the support/ dir

Thread.abort_on_exception = true

# Show backtraces for deprecated behavior for quicker cleanup.
ActiveSupport::Deprecation.debug = true

# Disable available locale checks to avoid warnings running the test suite.
I18n.enforce_available_locales = false

# Connect to the database
ARTest.connect

def load_schema
  # silence verbose schema loading
  original_stdout = $stdout
  $stdout = StringIO.new

  adapter_name = ActiveRecord::Base.connection.adapter_name.downcase
  adapter_specific_schema_file = SCHEMA_ROOT + "/#{adapter_name}_specific_schema.rb"

  # load SCHEMA_ROOT + "/schema.rb"

  if File.exist?(adapter_specific_schema_file)
    load adapter_specific_schema_file
  end

  ActiveRecord::FixtureSet.reset_cache
ensure
  $stdout = original_stdout
end

load_schema

class SQLSubscriber
  attr_reader :logged
  attr_reader :payloads

  def initialize
    @logged = []
    @payloads = []
  end

  def start(name, id, payload)
    @payloads << payload
    @logged << [payload[:sql].squish, payload[:name], payload[:binds]]
  end

  def finish(name, id, payload); end
end