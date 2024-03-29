# frozen_string_literal: true

require "fb"
require "base64"
require "arel"
require "arel/visitors/rdb_visitor"
require "active_record/rdb_patches/sql_literal_patch"

require "active_record"
require "active_record/base"
require "active_record/connection_adapters/abstract_adapter"
require "active_record/connection_adapters/rdb/database_statements"
require "active_record/connection_adapters/rdb/database_limits"
require "active_record/connection_adapters/rdb/schema_definitions"
require "active_record/connection_adapters/rdb/schema_creation"
require "active_record/connection_adapters/rdb/schema_dumper"
require "active_record/connection_adapters/rdb/schema_statements"
require "active_record/connection_adapters/rdb/quoting"
require "active_record/connection_adapters/rdb_column"
require "active_record/connection_adapters/rdb/type_metadata"

module ActiveRecord
  module ConnectionHandling # :nodoc:
    # Establishes a connection to the database that's used by all Active Record objects
    def rdb_connection(config)
      config = rdb_connection_config(config)

      # Initialize Database with Hash of values:
      #  :database:: Full Firebird connection string, e.g. 'localhost:/var/fbdata/drivertest.fdb' (required)
      #  :username:: database username (default: 'sysdba')
      #  :password:: database password (default: 'masterkey')
      #  :charset:: character set to be used with the connection (default: 'NONE')
      #  :role:: database role to connect using (default: nil)
      #  :downcase_names:: Column names are reported in lowercase, unless they were originally mixed case (default: nil).
      #  :encoding:: connection encoding (default: ASCII-8BIT)
      #  :page_size:: page size to use when creating a database (default: 4096)
      db = ::Fb::Database.new(config).connect

      ConnectionAdapters::RdbAdapter.new(db, logger, config)
    rescue ::Fb::Error => error
      if error.message.include?("No such file or directory")
        raise ActiveRecord::NoDatabaseError
      else
        pp config
        raise ActiveRecord::ConnectionNotEstablished, error.message
      end
    end

    def rdb_connection_config(config)
      config = config.symbolize_keys.dup.reverse_merge(downcase_names: true)

      # Require database.
      unless config[:database]
        raise ArgumentError, "No database file specified. Missing argument: database"
      end

      # Generate full connection string as extension requires
      # If host or port not specified in config
      # Defaults to 0.0.0.0 and 3050 respectively
      host = config.fetch(:host) { "0.0.0.0" }
      port = config.fetch(:port) { "3050" }
      config[:database] = "#{host}/#{port}:#{config[:database]}"
      config
    end
  end

  module ConnectionAdapters
    class RdbAdapter < AbstractAdapter # :nodoc:
      ADAPTER_NAME = "RedDatabase"

      include Rdb::DatabaseLimits
      include Rdb::DatabaseStatements
      include Rdb::Quoting
      include Rdb::SchemaStatements

      @@default_transaction_isolation = :read_committed
      cattr_accessor :default_transaction_isolation

      def initialize(connection, logger = nil, config = {})
        super(connection, logger, config)
        # Our Responsibility
        @config = config
      end

      def arel_visitor
        Arel::Visitors::Rdb.new self
      end

      def valid_type?(type)
        !native_database_types[type].nil? || !native_database_types[type.type].nil?
      end

      def adapter_name
        ADAPTER_NAME
      end

      def schema_creation
        Rdb::SchemaCreation.new self
      end

      def supports_migrations?
        true
      end

      def supports_primary_key?
        true
      end

      def supports_count_distinct?
        true
      end

      # AR wraps all migrations in a transaction and rollbacks it if there is a error.
      # Firebird doesn't support mixing of DDL and DML statements in one transaction.
      # In other words, there is no way to use CREATE TABLE and INSERT INTO within a single transaction.
      def supports_ddl_transactions?
        false
      end

      def supports_transaction_isolation?
        true
      end

      def supports_savepoints?
        true
      end

      def prefetch_primary_key?(_table_name = nil)
        true
      end

      def ids_in_list_limit
        1499
      end

      def supports_multi_insert?
        false
      end

      def supports_datetime_with_precision?
        false
      end

      def supports_lazy_transactions?
        true
      end

      def active?
        return false unless @connection.open?

        @connection.query("SELECT 1 FROM RDB$DATABASE")
        true
      rescue StandardError
        false
      end

      def reconnect!
        disconnect!
        @connection = ::Fb::Database.connect(@config)
      end

      def disconnect!
        super
        begin
          @connection.close
        rescue StandardError
          nil
        end
      end

      def reset!
        reconnect!
      end

      def requires_reloading?
        false
      end

      def create_savepoint(name = current_savepoint_name)
        execute("SAVEPOINT #{name}")
      end

      def rollback_to_savepoint(name = current_savepoint_name)
        execute("ROLLBACK TO SAVEPOINT #{name}")
      end

      def release_savepoint(name = current_savepoint_name)
        execute("RELEASE SAVEPOINT #{name}")
      end

      def encoding
        @connection.encoding
      end

      def get_database_version # :nodoc:
        RdbAdapter::Version.new(query_value("select rdb$get_context('SYSTEM', 'ENGINE_VERSION') as version from rdb$database;"))
      end

      protected
        def initialize_type_map(m = type_map)
          super
          m.register_type(%r(timestamp)i, Type::DateTime.new)
          m.register_type(%r(bigint)i, Type::Integer.new(limit: 8))
          m.alias_type(%r(blob sub_type text)i, "text")
          m.alias_type(%r(blob sub_type binary)i, "binary")
        end

        def translate_exception(exception, message:, sql:, binds:)
          case exception.message
          when /violation of FOREIGN KEY constraint/
            ActiveRecord::InvalidForeignKey.new(message, sql: sql, binds: binds)
          when /violation of PRIMARY or UNIQUE KEY constraint/, /attempt to store duplicate value/
            ActiveRecord::RecordNotUnique.new(message, sql: sql, binds: binds)
          when /This operation is not defined for system tables/
            ActiveRecord::ActiveRecordError.new(message)
          when /Column does not belong to referenced table/,
            /Unsuccessful execution caused by system error that does not preclude successful execution of subsequent statements/,
            /The cursor identified in the UPDATE or DELETE statement is not positioned on a row/,
            /Overflow occurred during data type conversion/
            ActiveRecord::StatementInvalid.new(message, sql: sql, binds: binds)
          else
            super
          end
        end
    end
  end
end
