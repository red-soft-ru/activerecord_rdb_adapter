# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Rdb
      module ColumnMethods
        extend ActiveSupport::Concern

        attr_accessor :needs_sequence

        def primary_key(name, type = :primary_key, **options)
          self.needs_sequence = true
          super
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        def references(*args, **options)
          args.each do |ref_name|
            Rdb::ReferenceDefinition.new(ref_name, **options).add_to(self)
          end
        end
        alias :belongs_to :references
      end

      class ReferenceDefinition < ActiveRecord::ConnectionAdapters::ReferenceDefinition
        private
          def polymorphic_index_name(table_name)
            index_name = super
            return index_name unless index_name.length > ActiveRecord::Base.connection.table_alias_length

            "IDX_#{Digest::SHA1.hexdigest(index_name)[0..22]}"
          end
      end
    end
  end
end
