# frozen_string_literal: true

require "test_helper"
require "models/bar"

class RdbAdapterTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.rdb_connection(ARTest.config["default"])
  end

  def test_bad_connection
    assert_raises ActiveRecord::ConnectionNotEstablished, ("No database connection established") do
      ActiveRecord::Base.rdb_connection(adapter: "rdb", database: "/tmp/should/_not/_exist/-cinco-dog.db")
    end
  end

  def test_config_should_have_database_key
    assert_raises ActiveRecord::ConnectionNotEstablished do
      ActiveRecord::Base.rdb_connection(adapter: "rdb", user: "sysdba", password: "masterkey")
    end
  end

  def test_connect
    assert @connection, "should have connect"
  end

  def test_encoding
    assert_equal ARTest.config["default"]["encoding"], @connection.encoding
  end

  def test_uniqueness_violations_are_translated_to_specific_exception
    @connection.execute "INSERT INTO foos (v) VALUES(1)"
    error = assert_raises(ActiveRecord::RecordNotUnique) do
      @connection.execute "INSERT INTO foos (id) VALUES(1)"
    end

    assert_not_nil error.cause
  end

  def test_foreign_key_violations_are_translated_to_specific_exception
    @connection.execute %{alter table bars add fk integer references bars}
    error = assert_raises(ActiveRecord::InvalidForeignKey) do
      @connection.execute %{insert into bars (v1, fk) values ('3', 1000)}
    end

    assert_not_nil error.cause
  end

  def test_should_escape_reserved_words
    assert_equal Bar.select("position").to_sql, %{SELECT "POSITION" FROM "BARS"}
    assert_equal Bar.select("value").to_sql, %{SELECT "VALUE" FROM "BARS"}
    assert_equal Bar.select("count").to_sql, %{SELECT "COUNT" FROM "BARS"}
    assert_match(/count/, Bar.select("count(*)").to_sql)
  end

  def test_offset_operator
    assert_equal Bar.select("*").offset(10).to_sql, %{SELECT * FROM "BARS" OFFSET 10 ROWS}
  end
end
