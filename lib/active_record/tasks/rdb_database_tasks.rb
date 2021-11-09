# frozen_string_literal: true

module ActiveRecord
  module Tasks # :nodoc:
    class RdbDatabaseTasks # :nodoc:
      delegate :rdb_connection, :establish_connection, to: ::ActiveRecord::Base

      def initialize(db_config)
        @db_config = db_config
      end

      def create
        rdb_database.create
      rescue ::Fb::Error => e
        raise unless e.message.include?("File exists")
        raise DatabaseAlreadyExists
      end

      def drop
        establish_connection(db_config)
        rdb_database.drop
      rescue StandardError => error
        raise NoDatabaseError if error.message.include?("No such file or directory")
        $stderr.puts error
        $stderr.puts "Couldn't drop database '#{db_config[:database]}'"
        raise
      end

      def purge
        drop
      rescue StandardError
        nil
      ensure
        create
      end
      # ================================================================
      # TODO: probably not working
      def structure_dump(filename, structure_dump_flags = nil)
        isql :extract, output: filename
      end

      def structure_load(filename, structure_load_flags = nil)
        isql input: filename
      end
      # ================================================================

      private
        def rdb_database
          ::Fb::Database.new(db_config)
        end

        # TODO: probably not working
        # Executes isql commands to load/dump the schema.
        # The generated command might look like this:
        #   isql db/development.fdb -user SYSDBA -password masterkey -extract
        def isql(*args)
          opts = args.extract_options!
          user, pass = db_config.values_at(:username, :password)
          user ||= db_config[:user]
          opts.reverse_merge!(user: user, password: pass)
          cmd = [isql_executable, db_config[:database]]
          cmd += opts.map { |name, val| "-#{name} #{val}" }
          cmd += args.map { |flag| "-#{flag}" }
          cmd = cmd.join(" ")
          raise "Error running: #{cmd}" unless Kernel.system(cmd)
        end

        # TODO: probably not working
        def isql_create(*_args)
          "#{isql_executable} -input "
        end

        # Finds the isql command line utility from the PATH
        # Many linux distros call this program isql-fb, instead of isql
        def isql_executable
          require "mkmf"
          exe =
            if find_executable "docker"
              "docker exec -it RedDatabase isql"
            else
              %w[isql-fb isql].detect(&method(:find_executable0))
            end

          exe || abort("Unable to find isql or isql-fb in your $PATH")
        end

      private
        attr_reader :db_config
    end
  end
end
