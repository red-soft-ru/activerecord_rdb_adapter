# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module Rdb
      module SchemaStatements # :nodoc:
        methods_to_commit = %i[add_column
                               change_column
                               change_column_default
                               change_column_null
                               create_sequence
                               create_table
                               drop_sequence
                               drop_table
                               drop_trigger
                               remove_column
                               remove_index
                               remove_index!
                               rename_column]

        def tables(_name = nil)
          @connection.table_names
        end

        def views
          @connection.view_names
        end

        def indexes(table_name, _name = nil)
          @connection.indexes.values.filter_map do |ix|
            IndexDefinition.new(table_name, ix.index_name, ix.unique, ix.columns) if ix.table_name == table_name.to_s && ix.index_name !~ /^rdb\$/
          end
        end

        def index_name_exists?(table_name, index_name)
          index_name = index_name.to_s.upcase
          indexes(table_name).detect { |i| i.name.upcase == index_name }
        end

        def columns(table_name, _name = nil)
          @col_definitions ||= {}
          @col_definitions[table_name] = column_definitions(table_name).map do |field|
            new_column_from_field(table_name, field)
          end
        end

        def create_table(name, options = {}) # :nodoc:
          raise ActiveRecordError, "Firebird does not support temporary tables" if options.key? :temporary

          raise ActiveRecordError, "Firebird does not support creating tables with a select" if options.key? :as

          drop_table name, if_exists: true if options.key? :force

          needs_sequence = options[:id]

          super name, options do |table_def|
            yield table_def if block_given?
            needs_sequence ||= table_def.needs_sequence
          end

          return if options[:sequence] == false || !needs_sequence

          create_sequence(options[:sequence] || default_sequence_name(name))
          trg_sql = <<-END_SQL
            CREATE TRIGGER N$#{name.upcase} FOR #{name.upcase}
            ACTIVE BEFORE INSERT
            AS
            declare variable gen_val bigint;
            BEGIN
              if (new.ID is null) then
                new.ID = next value for #{options[:sequence] || default_sequence_name(name)};
              else begin
                gen_val = gen_id(#{options[:sequence] || default_sequence_name(name)}, 1);
                if (new.ID > gen_val) then
                  gen_val = gen_id(#{options[:sequence] || default_sequence_name(name)}, new.ID - gen_val);
              end
            END
          END_SQL
          execute(trg_sql)
        end

        def drop_table(name, options = {}) # :nodoc:
          drop_sql = "DROP TABLE #{quote_table_name(name)}"
          drop = if options[:if_exists]
            !execute(squish_sql(<<-END_SQL))
          select 1 from rdb$relations where rdb$relation_name = #{quote_table_name(name).tr('"', '\'')}
            END_SQL
                 .empty?
          else
            false
          end

          trigger_name = "N$#{name.upcase}"
          drop_trigger(trigger_name) if trigger_exists?(trigger_name)

          sequence_name = options[:sequence] || default_sequence_name(name)
          drop_sequence(sequence_name) if sequence_exists?(sequence_name)

          execute(drop_sql) if drop
        end

        def create_sequence(sequence_name)
          execute("CREATE SEQUENCE #{sequence_name}")
        rescue StandardError
          nil
        end

        def drop_sequence(sequence_name)
          execute("DROP SEQUENCE #{sequence_name}")
        rescue StandardError
          nil
        end

        def drop_trigger(trigger_name)
          execute("DROP TRIGGER #{trigger_name}")
        rescue StandardError
          nil
        end

        def sequence_exists?(sequence_name)
          @connection.generator_names.include?(sequence_name)
        end

        def trigger_exists?(trigger_name)
          !execute(squish_sql(<<-END_SQL))
            select 1
            from rdb$triggers
             where rdb$trigger_name = '#{trigger_name}'
          END_SQL
            .empty?
        end

        def add_column(table_name, column_name, type, options = {})
          super

          create_sequence(options[:sequence] || default_sequence_name(table_name)) if type == :primary_key && options[:sequence] != false

          return unless options[:position]

          # position is 1-based but add 1 to skip id column
          execute(squish_sql(<<-END_SQL))
            ALTER TABLE #{quote_table_name(table_name)}
            ALTER COLUMN #{quote_column_name(column_name)}
            POSITION #{options[:position] + 1}
          END_SQL
        end

        def remove_column(table_name, column_name, type = nil, options = {})
          indexes(table_name).each do |i|
            remove_index! i.table, i.name if i.columns.any? { |c| c == column_name.to_s }
          end

          column_exist = !execute(squish_sql(<<-END_SQL))
          select 1 from RDB$RELATION_FIELDS rf
            where lower(rf.RDB$RELATION_NAME) = '#{table_name.downcase}' and lower(rf.RDB$FIELD_NAME) = '#{column_name.downcase}'
          END_SQL
                         .empty?
          super if column_exist
        end

        def remove_column_for_alter(_table_name, column_name, _type = nil, _options = {})
          "DROP #{quote_column_name(column_name)}"
        end

        def change_column(table_name, column_name, type, options = {})
          type_sql = type_to_sql(type, *options.values_at(:limit, :precision, :scale))

          if %i[text string].include?(type)
            copy_column = "c_temp"
            add_column table_name, copy_column, type, options
            execute(squish_sql(<<-END_SQL))
            UPDATE #{table_name} SET #{quote_column_name(copy_column)} = #{quote_column_name(column_name)};
            END_SQL
            remove_column table_name, column_name
            rename_column table_name, copy_column, column_name
          else
            execute(squish_sql(<<-END_SQL))
            ALTER TABLE #{quote_table_name(table_name)}
            ALTER COLUMN #{quote_column_name(column_name)} TYPE #{type_sql}
            END_SQL
          end
          change_column_null(table_name, column_name, !!options[:null]) if options.key?(:null)
          change_column_default(table_name, column_name, options[:default]) if options.key?(:default)
        end

        def change_column_default(table_name, column_name, default)
          execute(squish_sql(<<-END_SQL))
            ALTER TABLE #{quote_table_name(table_name)}
            ALTER #{quote_column_name(column_name)}
            SET DEFAULT #{quote(default)}
          END_SQL
        end

        def change_column_null(table_name, column_name, null, default = nil)
          change_column_default(table_name, column_name, default) if default

          db_column = columns(table_name).find { |c| c.name == column_name.to_s }
          options = { null: null }
          options[:default] = db_column.default if !default && db_column.default
          options[:default] = default if default
          ar_type = db_column.type
          type = type_to_sql(ar_type.type, ar_type.limit, ar_type.precision, ar_type.scale)

          copy_column = "c_temp"
          add_column table_name, copy_column, type, options
          execute(squish_sql(<<-END_SQL))
            UPDATE #{table_name} SET #{quote_column_name(copy_column)} = #{quote_column_name(column_name)};
          END_SQL
          remove_column table_name, column_name
          rename_column table_name, copy_column, column_name
        end

        def rename_column(table_name, column_name, new_column_name)
          execute(squish_sql(<<-END_SQL))
            ALTER TABLE #{quote_table_name(table_name)}
            ALTER #{quote_column_name(column_name)}
            TO #{quote_column_name(new_column_name)}
          END_SQL

          rename_column_indexes(table_name, column_name, new_column_name)
        end

        def remove_index!(_table_name, index_name)
          execute "DROP INDEX #{quote_column_name(index_name)}"
        end

        def remove_index(table_name, column_name = nil, **options)
          index_name = index_name(table_name, options)
          execute "DROP INDEX #{quote_column_name(index_name)}"
        end

        def index_name(table_name, options) # :nodoc:
          if Hash === options
            if options[:column]
              index_name = "index_#{table_name}_on_#{Array(options[:column]) * '_and_'}"
              if index_name.length > table_alias_length
                "IDX_#{Digest::SHA256.hexdigest(index_name)[0..22]}"
              else
                index_name
              end
            elsif options[:name]
              options[:name]
            else
              raise ArgumentError "You must specify the index name"
            end
          else
            index_name(table_name, index_name_options(options))
          end
        end

        def index_exists?(table_name, column_name, options = {})
          column_names = Array(column_name).map(&:to_s)
          checks = []
          checks << lambda { |i| i.columns == column_names }
          checks << lambda(&:unique) if options[:unique]
          checks << lambda { |i| i.name.upcase == options[:name].to_s.upcase } if options[:name]

          indexes(table_name).any? { |i| checks.all? { |check| check[i] } }
        end

        def type_to_sql(type, limit = nil, precision = nil, scale = nil, **args)
          if !args.nil? && !args.empty?
            limit = args[:limit] if limit.nil?
            precision = args[:precision] if precision.nil?
            scale = args[:scale] if scale.nil?
          end
          case type
          when :integer
            integer_to_sql(limit)
          when :float
            float_to_sql(limit)
          when :text
            text_to_sql(limit)
          # when :blob
          #   binary_to_sql(limit)
          when :string
            string_to_sql(limit)
          else
            type = type.to_sym if type
            native = native_database_types[type]
            if native
              column_type_sql = (native.is_a?(Hash) ? native[:name] : native).dup

              if type == :decimal # ignore limit, use precision and scale
                scale ||= native[:scale]

                if precision ||= native[:precision]
                  column_type_sql << if scale
                    "(#{precision},#{scale})"
                  else
                    "(#{precision})"
                  end
                elsif scale
                  raise ArgumentError, "Error adding decimal column: precision cannot be empty if scale is specified"
                end

              elsif %i[datetime timestamp time interval].include?(type) && precision ||= native[:precision]
                if (0..6) === precision
                  column_type_sql << "(#{precision})"
                else
                  raise(ActiveRecordError, "No #{native[:name]} type has precision of #{precision}. The allowed range of precision is from 0 to 6")
                end
              elsif (type != :primary_key) && (limit ||= native.is_a?(Hash) && native[:limit])
                column_type_sql << "(#{limit})"
              end

              column_type_sql
            else
              type.to_s
            end
          end
        end

        def primary_key(table_name)
          row = @connection.query(<<-END_SQL)
            SELECT s.rdb$field_name
            FROM rdb$indices i
            JOIN rdb$index_segments s ON i.rdb$index_name = s.rdb$index_name
            LEFT JOIN rdb$relation_constraints c ON i.rdb$index_name = c.rdb$index_name
            WHERE i.rdb$relation_name = '#{ar_to_rdb_case(table_name)}'
            AND c.rdb$constraint_type = 'PRIMARY KEY';
          END_SQL

          row.first && rdb_to_ar_case(row.first[0].rstrip)
        end

        def native_database_types
          @native_database_types ||= initialize_native_database_types.freeze
        end

        def create_schema_dumper(options)
          Rdb::SchemaDumper.create(self, options)
        end

        def assume_migrated_upto_version(version)
          version = version.to_i
          sm_table = quote_table_name(schema_migration.table_name)

          migrated = migration_context.get_all_versions
          versions = migration_context.migrations.map(&:version)

          unless migrated.include?(version)
            execute "INSERT INTO #{sm_table} (#{quote_column_name('version')}) VALUES (#{quote(version)})"
          end

          inserting = (versions - migrated).select { |v| v < version }
          if inserting.any?
            if (duplicate = inserting.detect { |v| inserting.count(v) > 1 })
              raise "Duplicate migration #{duplicate}. Please renumber your migrations to resolve the conflict."
            end

            statements = insert_versions_sql(inserting)
            with_multi_statements do
              disable_referential_integrity do
                execute_batch(statements, "Versions Load")
              end
            end
          end
        end

        private
          def column_definitions(table_name)
            @connection.columns(table_name)
          end

          def new_column_from_field(table_name, field)
            type_metadata = column_type_for(field)
            rdb_opt = { domain: field[:domain], sub_type: field[:sql_subtype] }
            RdbColumn.new(field[:name], parse_default(field[:default]), type_metadata, field[:nullable], rdb_opt)
          end

          def column_type_for(field)
            sql_type = RdbColumn.sql_type_for(field)
            type = lookup_cast_type(sql_type)
            rdb_options = {
              domain: field[:domain],
              sub_type: field[:sql_subtype]
            }
            simple_type = SqlTypeMetadata.new(
              sql_type: sql_type,
              type: type,
              limit: type.limit,
              precision: type.precision,
              scale: type.scale
            )
            Rdb::TypeMetadata.new(simple_type, rdb_options)
          end

          def parse_default(default)
            return if default.nil? || /null/i.match?(default)

            d = default.dup
            d.gsub!(/^\s*DEFAULT\s+/i, "")
            d.gsub!(/(^'|'$)/, "")
            d
          end

          def integer_to_sql(limit)
            return "integer" if limit.nil?

            case limit
            when 1..2 then
              "smallint"
            when 3..4 then
              "integer"
            when 5..8 then
              "bigint"
            else
              raise ActiveRecordError "No integer type has byte size #{limit}. " \
                                      "Use a NUMERIC with PRECISION 0 instead."
            end
          end

          def float_to_sql(limit)
            limit.nil? || limit <= 4 ? "float" : "double precision"
          end

          def text_to_sql(limit)
            if limit && limit > 0
              "VARCHAR(#{limit})"
            else
              "BLOB SUB_TYPE TEXT"
            end
          end

          def string_to_sql(limit)
            if limit && limit > 0 && limit < 255
              "VARCHAR(#{limit})"
            else
              "VARCHAR(255)"
            end
          end

          def initialize_native_database_types
            {
              primary_key: "bigint not null primary key",
              string: { name: "varchar", limit: 255 },
              text: { name: "blob sub_type text" },
              integer: { name: "integer" },
              bigint: { name: "bigint" },
              float: { name: "float" },
              decimal: { name: "decimal" },
              datetime: { name: "timestamp" },
              timestamp: { name: "timestamp" },
              time: { name: "time" },
              date: { name: "date" },
              binary: { name: "blob sub_type binary" },
              boolean: { name: "boolean" }
            }
          end

          def create_table_definition(name, **options)
            Rdb::TableDefinition.new(self, name, **options)
          end

          def squish_sql(sql)
            sql.strip.gsub(/\s+/, " ")
          end

          class << self
            def after(*names)
              names.flatten.each do |name|
                m = ActiveRecord::ConnectionAdapters::Rdb::SchemaStatements.instance_method(name)
                define_method(name) do |*args, &block|
                  m.bind_call(self, *args, &block)
                  yield
                  commit_db_transaction
                end
              end
            end
          end

          after(methods_to_commit) { |_| }

          def insert_versions_sql(versions)
            sm_table = quote_table_name(schema_migration.table_name)

            if versions.is_a?(Array)
              versions.map { |v| "INSERT INTO #{sm_table} (#{quote_column_name('version')}) VALUES (#{quote(v)});" }
            else
              ["INSERT INTO #{sm_table} (#{quote_column_name('version')}) VALUES (#{quote(versions)});"]
            end
          end
      end
    end
  end
end
