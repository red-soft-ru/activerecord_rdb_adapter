module ActiveRecord
  module ConnectionAdapters
    module Rdb
      class SchemaDumper < ConnectionAdapters::SchemaDumper # :nodoc:
        private

        def column_spec_for_primary_key(column)
          spec = super
          spec.delete(:auto_increment) if column.type == :integer && column.auto_increment?
          spec
        end

        def schema_type(column)
          if column.bigint?
            :bigint
          else
            column.type.type
          end
        end

        def schema_limit(column)
          limit = column.limit unless column.bigint?
          limit.inspect if limit && limit != @connection.native_database_types[column.type.type][:limit]
        end

        def explicit_primary_key_default?(column)
          true
        end
      end
    end
  end
end
