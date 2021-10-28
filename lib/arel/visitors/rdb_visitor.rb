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
        elsif !o.limit && o.offset
          collector = visit o.offset, collector
        end
        maybe_visit o.lock, collector

        collector
      end

      def visit_Arel_Nodes_Limit(o, collector)
        collector << ' ROWS '
        visit o.expr, collector
      end

      def visit_Arel_Nodes_Offset(o, collector)
        collector << ' OFFSET '
        visit o.expr, collector
        collector << ' ROWS'
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

      def visit_Arel_Nodes_In(o, collector)
        unless Array === o.right
          return collect_in_clause(o.left, o.right, collector)
        end

        unless o.right.empty?
          o.right.delete_if { |value| unboundable?(value) }
        end

        return collector << "1=0" if o.right.empty?

        in_clause_length = @connection.in_clause_length

        if !in_clause_length || o.right.length <= in_clause_length
          collect_in_clause(o.left, o.right, collector)
        else
          collector << "("
          o.right.each_slice(in_clause_length).each_with_index do |right, i|
            collector << " OR " unless i == 0
            collect_in_clause(o.left, right, collector)
          end
          collector << ")"
        end
      end

      def collect_in_clause(left, right, collector)
        collector = visit left, collector
        collector << " IN ("
        visit(right, collector) << ")"
      end

      def visit_Arel_Nodes_NotIn(o, collector)
        unless Array === o.right
          return collect_not_in_clause(o.left, o.right, collector)
        end

        unless o.right.empty?
          o.right.delete_if { |value| unboundable?(value) }
        end

        return collector << "1=1" if o.right.empty?

        in_clause_length = @connection.in_clause_length

        if !in_clause_length || o.right.length <= in_clause_length
          collect_not_in_clause(o.left, o.right, collector)
        else
          o.right.each_slice(in_clause_length).each_with_index do |right, i|
            collector << " AND " unless i == 0
            collect_not_in_clause(o.left, right, collector)
          end
          collector
        end
      end

      def collect_not_in_clause(left, right, collector)
        collector = visit left, collector
        collector << " NOT IN ("
        visit(right, collector) << ")"
      end

      def visit_Arel_Nodes_HomogeneousIn(o, collector)
        # slice (NOT) IN clause if values more then @connection.in_clause_length
        if Array === o.right && o.casted_values.size > @connection.in_clause_length
          if o.type == :in
            return visit_Arel_Nodes_In(o, collector)
          else
            return visit_Arel_Nodes_NotIn(o, collector)
          end
        end

        collector.preparable = false

        collector << quote_table_name(o.table_name) << "." << quote_column_name(o.column_name)

        if o.type == :in
          collector << " IN ("
        else
          collector << " NOT IN ("
        end

        values = o.casted_values

        if values.empty?
          collector << @connection.quote(nil)
        else
          collector.add_binds(values, o.proc_for_binds, &bind_block)
        end

        collector << ")"
        collector
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
