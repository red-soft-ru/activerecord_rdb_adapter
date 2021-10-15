# frozen_string_literal: true

require "test_helper"
require "models/bar"

class RdbDatabaseStatements < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.rdb_connection(ARTest.config["default"])
  end

  def teardown
    super
    connection.drop_table :testings rescue nil
  end

  def test_config_should_have_database_key
    assert_raises ActiveRecord::ConnectionNotEstablished do
      ActiveRecord::Base.rdb_connection(adapter: "rdb", user: "sysdba", password: "masterkey")
    end
  end

  def test_bulk_insert_fixtures
    fixtures = {
      "bars" => [
        { "v1" => "1", "v2" => "1", "v3" => "1", "created_date" => Date.current },
        { "v1" => "2", "v2" => "2", "v3" => "2", "created_date" => Date.current },
        { "v1" => "3", "v2" => "3", "v3" => "3", "created_date" => Date.current }
      ]
    }

    assert_difference "Bar.count", +3 do
      @connection.insert_fixtures_set(fixtures)
    end
  end

  def test_default_insert_value
    @connection.create_table :testings, force: true do |t|
      t.string  :one, default: nil
      t.boolean :two, default: true
      t.integer :three, default: 1
      t.string  :four, default: ""
      t.string  :five
    end
    fixture_set = { "testings" => [ "five" => "somestring" ] }
    @connection.insert_fixtures_set(fixture_set)

    created_fixture = ActiveRecord::Base.connection.select_one("SELECT * FROM testings")
    assert_nil created_fixture["one"]
    assert created_fixture["two"].kind_of? TrueClass
    assert created_fixture["three"].kind_of? Integer
    assert_equal created_fixture["four"], ""
    assert_equal created_fixture["five"], "somestring"
  end
end
