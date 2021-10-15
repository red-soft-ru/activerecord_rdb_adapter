# frozen_string_literal: true

module Arel # :nodoc: all
  module Visitors
    class Rdb < Arel::Visitors::ToSql # :nodoc
      private

      def visit_Arel_Nodes_InsertStatement(o, collector)
        collector << "INSERT INTO "
        collector = visit o.relation, collector

        unless o.columns.empty?
          collector << " ("
          o.columns.each_with_index do |x, i|
            collector << ", " unless i == 0
            collector << quote_column_name(x.name)
          end
          collector << ")"
        end

        if o.values
          maybe_visit o.values, collector
        elsif o.select
          maybe_visit o.select, collector
        else
          collector
        end
      end

      def visit_Arel_Nodes_SelectCore(o, collector, select_statement)
        collector << 'SELECT'

        collector = collect_optimizer_hints(o, collector)
        collector = maybe_visit o.set_quantifier, collector

        collect_nodes_for o.projections, collector, ' '

        if o.source && !o.source.empty?
          collector << ' FROM '
          collector = visit o.source, collector
        end

        collect_nodes_for o.wheres, collector, ' WHERE ', ' AND '
        collect_nodes_for o.groups, collector, ' GROUP BY '
        unless o.havings.empty?
          collector << ' HAVING '
          inject_join o.havings, collector, ' AND '
        end
        collect_nodes_for o.windows, collector, ' WINDOW '

        collector
      end

      def visit_Arel_Nodes_SelectStatement(o, collector)
        if o.with
          collector = visit o.with, collector
          collector << ' '
        end

        collector = o.cores.inject(collector) { |c,x|
          visit_Arel_Nodes_SelectCore(x, c, o)
        }

        unless o.orders.empty?
          collector << ' ORDER BY '
          len = o.orders.length - 1
          o.orders.each_with_index { |x, i|
            collector = visit(x, collector)
            collector << ', ' unless len == i
          }
        end

        if o.limit && o.offset
          collector = limit_with_rows(o, collector)
        elsif o.limit && !o.offset
          collector = visit o.limit, collector
        end
        maybe_visit o.lock, collector

        collector
      end

      def visit_Arel_Nodes_Limit(o, collector)
        collector << ' ROWS '
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Offset(o, collector)
        collector << ' SKIP '
        visit o.expr, collector
      end

      def limit_with_rows(o, collector)
        offset = ActiveModel::Attribute.with_cast_value('OFFSET'.freeze,
                                                                     o.offset.expr.value.value + 1,
                                                                     ActiveModel::Type.default_value)
        limit =  ActiveModel::Attribute.with_cast_value('LIMIT'.freeze,
                                                                    o.limit.expr.value.value + (offset.value - 1),
                                                                    ActiveModel::Type.default_value)
        collector << ' ROWS '
        collector.add_bind(offset, &bind_block)
        collector << ' TO '
        collector.add_bind(limit, &bind_block)
      end

      def quote_column_name name
        return name if Arel::Nodes::SqlLiteral === name

        @connection.quote_column_name(name)
      end

      def visit_Arel_Nodes_Union(o, collector)
        infix_value(o, collector, ' UNION ')
      end

      def visit_Arel_Nodes_UnionAll(o, collector)
        infix_value(o, collector, ' UNION ALL ')
      end
    end
  end
end
