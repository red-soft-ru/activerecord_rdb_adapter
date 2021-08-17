# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    class RdbColumn < Column # :nodoc:
      delegate :sub_type, :domain, to: :sql_type_metadata, allow_nil: true

      class << self
        def sql_type_for(field)
          sql_type = field[:sql_type]
          sub_type = field[:sql_subtype]

          sql_type << case sql_type
                      when /(numeric|decimal)/i
                        "(#{field[:precision]},#{field[:scale].abs})"
                      when /(int|float|double|char|varchar|bigint)/i
                        "(#{field[:length]})"
                      else
                        ''
                      end

          sql_type << ' sub_type text' if /blob/i.match?(sql_type) && sub_type == 1
          sql_type
        end
      end

      private

      def parse_default(default)
        return if default.nil? || /null/i.match?(default)
        d = default.dup
        d.gsub!(/^\s*DEFAULT\s+/i, '')
        d.gsub!(/(^'|'$)/, '')
        d
      end

      def simplified_type(field_type)
        return :datetime if /timestamp/i.match?(field_type)
        return :text if /blob sub_type text/i.match?(field_type)
        super
      end
    end
  end
end
