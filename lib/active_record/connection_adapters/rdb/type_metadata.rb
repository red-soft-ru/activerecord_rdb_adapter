# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Rdb
      class TypeMetadata < DelegateClass(SqlTypeMetadata) # :nodoc:
        undef to_yaml if method_defined?(:to_yaml)

        include Deduplicable

        attr_reader :sub_type, :domain

        def initialize(type_metadata, rdb_options = {})
          super(type_metadata)
          @sub_type = rdb_options[:sub_type]
          @domain = rdb_options[:domain]
        end

        def ==(other)
          other.is_a?(TypeMetadata) &&
            __getobj__ == other.__getobj__ &&
            sub_type == other.sub_type &&
            domain == other.domain
        end
        alias eql? ==

        def hash
          TypeMetadata.hash ^
            __getobj__.hash ^
            sub_type.hash ^
            domain.hash
        end

        private
          def deduplicated
            __setobj__(__getobj__.deduplicate)
            @sub_type = -sub_type if sub_type
            @domain = -domain if domain
            super
          end
      end
    end
  end
end
