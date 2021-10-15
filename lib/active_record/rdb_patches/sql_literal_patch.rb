# frozen_string_literal: true

require 'active_support/concern'

module RdbPatches
  module SqlLiteralPatch
    extend ActiveSupport::Concern

    included do
      prepend InstanceOverwriteMethods
    end

    # Escapes reserved words in query:
    #   position => "POSITION"
    #   value    => "VALUE"
    #   count    => "COUNT"
    module InstanceOverwriteMethods
      def to_s
        self.gsub(/(?<=[^"\w]|^)(?:position|value|count)(?=[^"\w()]|$)/i) do |x|
          column = x.dup
          column.delete!('"')
          column.upcase!
          %("#{column}")
        end
      end
    end
  end
end

unless Arel::Nodes::SqlLiteral.included_modules.include?(RdbPatches::SqlLiteralPatch)
  Arel::Nodes::SqlLiteral.include(RdbPatches::SqlLiteralPatch)
end
