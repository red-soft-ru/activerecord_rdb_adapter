# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :foos, force: true do |t|
    t.integer :v
  end

  create_table :bars, force: true do |t|
    t.string :v1, null: false
    t.string :v2
    t.string :v3
    t.date :created_date
  end

  create_table :rdb_types, force: true do |t|
    t.string    :type_string, limit: 10

    t.integer   :type_smallint, limit: 2
    t.integer   :type_integer
    t.integer   :type_bigint, limit: 8

    t.float     :type_float, limit: 4
    t.float     :type_double, limit: 8

    t.decimal   :type_decimal, precision: 10, scale: 2
    t.time      :type_time
    t.timestamp :type_timestamp
    t.datetime  :type_datetime
    t.date      :type_date
    t.boolean   :type_bool
    t.text      :type_text
    t.binary    :type_binary
  end
end
