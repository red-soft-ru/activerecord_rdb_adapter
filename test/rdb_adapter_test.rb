# frozen_string_literal: true

require "test_helper"
require "models/bar"

class RdbAdapterTest < ActiveRecord::TestCase
  def setup
    @connection = ActiveRecord::Base.rdb_connection(ARTest.config["default"])
  end

  def test_bad_connection
    config = ARTest.config["default"].dup
    config[:database] = "/tmp/should/_not/_exist/-cinco-dog.db"
    assert_raises ActiveRecord::NoDatabaseError, ("No database connection established") do
      ActiveRecord::Base.rdb_connection(config)
    end
  end

  def test_config_should_have_database_key
    assert_raises ArgumentError do
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
    @connection.execute %{alter table bars add fk bigint references bars}
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

  def test_early_return_from_transaction
    foo = Bar.create!(v1: "1")

    assert_not_deprecated do
      foo.with_lock do
        break
      end
    end
  end

  def test_in_clause_is_correctly_sliced
    Bar.connection.stub(:in_clause_length, 1) do
      assert_equal Bar.where(id: [1, 2], v1: "123").to_sql, %{SELECT "BARS".* FROM "BARS" WHERE ("BARS"."ID" IN (1) OR "BARS"."ID" IN (2)) AND "BARS"."V1" = '123'}
    end
  end

  def test_default_connection_string
    con_config = ActiveRecord::Base.rdb_connection_config(adapter: "rdb", database: "/db/test.fdb")

    assert_equal "0.0.0.0/3050:/db/test.fdb", con_config[:database]
  end

  def test_add_column_with_string_limit
    @connection.add_column :foos, :ip, :string, limit: "10"

    column = @connection.columns(:foos).detect { |c| c.name == "ip" }

    assert_not_nil column
    assert_equal column.limit, 10
  end
end
