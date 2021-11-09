# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Rdb
      module Quoting # :nodoc:
        QUOTED_FALSE = "false"
        QUOTED_TRUE = "true"

        QUOTED_POSITION = '"POSITION"'
        QUOTED_VALUE = '"VALUE"'

        def quote_string(string) # :nodoc:
          string.gsub(/'/, "''")
        end

        def quoted_date(time)
          if time.is_a?(Time) || time.is_a?(DateTime)
            time.localtime.strftime("%d.%m.%Y %H:%M:%S")
          else
            time.strftime("%d.%m.%Y")
          end
        end

        def quote_column_name(column_name) # :nodoc:
          column = column_name.dup.to_s
          column.gsub!(/(?<=[^"\w]|^)position(?=[^"\w]|$)/i, QUOTED_POSITION)
          column.gsub!(/(?<=[^"\w]|^)value(?=[^"\w]|$)/i, QUOTED_VALUE)
          column.gsub!(/(?<=[^"\w]|^)as count(?=[^"\w]|$)/i, 'AS "COUNT"')
          column.delete!('"')
          column.upcase!
          %("#{column}")
        end

        def quote_table_name_for_assignment(_table, attr)
          quote_column_name(attr)
        end

        def type_cast_from_column(column, value) # :nodoc:
          if column
            type = column.type || lookup_cast_type_from_column(column)
            if type.is_a?(ActiveRecord::Type::Serialized)
              value
            else
              type.serialize(value)
            end
          else
            value
          end
        end

        def lookup_cast_type_from_column(column) # :nodoc:
          type = column.try(:sql_type) || column.try(:type)
          lookup_cast_type(type)
        end

        private
          def id_value_for_database(value)
            primary_key = value.class.primary_key
            if primary_key
              value.instance_variable_get(:@attributes)[primary_key].value_for_database
            end
          end

          def _quote(value)
            case value
            when Time, DateTime
              "'#{value.strftime('%d.%m.%Y %H:%M:%S')}'"
            when Date
              "'#{value.strftime('%d.%m.%Y')}'"
            else
              super
            end
          end

          def rdb_to_ar_case(column_name)
            /[[:lower:]]/.match?(column_name) ? column_name : column_name.downcase
          end

          def ar_to_rdb_case(column_name)
            /[[:upper:]]/.match?(column_name) ? column_name : column_name.upcase
          end

          def encode_hash(value)
            if value.is_a?(Hash)
              value.to_yaml
            else
              value
            end
          end

          if defined? Encoding
            def decode(str)
              Base64.decode64(str).force_encoding(@connection.encoding)
            end
          else
            def decode(str)
              Base64.decode64(str)
            end
          end
      end
    end
  end
end
