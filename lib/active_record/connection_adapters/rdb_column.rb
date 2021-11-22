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
                        ""
          end
          if /blob/i.match?(sql_type)
            sql_type << if sub_type == 1
              " sub_type text"
            elsif sub_type == 0
              " sub_type binary"
            end
          end

          sql_type
        end
      end

      private
        def simplified_type(field_type)
          return :datetime if /timestamp/i.match?(field_type)
          return :text if /blob sub_type text/i.match?(field_type)
          return :binary if /blob sub_type binary/i.match?(field_type)
          super
        end
    end
  end
end
