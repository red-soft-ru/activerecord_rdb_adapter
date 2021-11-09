# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Rdb
      module DatabaseLimits # :nodoc:
        def max_identifier_length # :nodoc:
          31
        end

        def table_alias_length
          max_identifier_length
        end

        def column_name_length
          max_identifier_length
        end

        def table_name_length
          max_identifier_length
        end

        def index_name_length
          max_identifier_length
        end

        def indexes_per_table
          65_535
        end

        def in_clause_length
          1_499
        end

        def sql_query_length
          32_767
        end
      end
    end
  end
end
