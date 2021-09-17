# frozen_string_literal: true

# TODO:
# no monkey patch?
module Arel # :nodoc: all
  module Nodes
    class SqlLiteral < String
      # makes a firebird life simpler by escaping reserved words in query
      def to_s
        self.gsub(/(?<=[^"\w]|^)(?:position|value|as count)(?=[^"\w]|$)/i) do |x|
          column = x.dup
          column.delete!('"')
          column.upcase!
          %("#{column}")
        end
      end
    end
  end
end
