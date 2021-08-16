module ActiveRecord
  module ConnectionAdapters
    module Rdb
      class SchemaCreation < ActiveRecord::ConnectionAdapters::SchemaCreation # :nodoc:

        private

        def visit_ColumnDefinition(o)
          o.sql_type = type_to_sql(o.type, o.options)
          column_sql = "#{quote_column_name(o.name)} #{o.sql_type}"
          add_column_options!(column_sql, column_options(o)) unless o.type == :primary_key
          column_sql
        end

        def add_column_options!(sql, options)
          sql << " DEFAULT #{quote_default_expression(options[:default], options[:column])}" if options_include_default?(options)
          # must explicitly check for :null to allow change_column to work on migrations
          if !options[:null].nil? && !options[:null]
            sql << " NOT NULL"
          end
          if options[:auto_increment]
            sql << " AUTO_INCREMENT"
          end
          if options[:primary_key]
            sql << " PRIMARY KEY"
          end
          sql
        end

        def visit_TableDefinition(o)
          create_sql = "CREATE#{' TEMPORARY' if o.temporary} TABLE #{quote_table_name(o.name)} "

          statements = o.columns.map(&method(:accept))
          statements << accept(o.primary_keys) if o.primary_keys

          if supports_indexes_in_create?
            statements.concat(o.indexes.map { |column_name, options| index_in_create(o.name, column_name, options) })
          end

          if supports_foreign_keys?
            statements.concat(o.foreign_keys.map { |fk| accept fk })
          end

          if supports_check_constraints?
            statements.concat(o.check_constraints.map { |chk| accept chk })
          end

          create_sql << "(#{statements.join(', ')})" if statements.present?
          add_table_options!(create_sql, o)
          create_sql << " AS #{@conn.to_sql(o.as)}" if o.as
          create_sql
        end
      end
    end
  end
end