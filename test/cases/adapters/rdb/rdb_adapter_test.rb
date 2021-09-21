# frozen_string_literal: true

require "cases/rdb_helper"
require "support/ddl_helper"
require "support/connection_helper"

module ActiveRecord
  module ConnectionAdapters
    include ActiveRecord::TestCase

    class RdbBaseTest < ActiveRecord::TestCase
      include DdlHelper
      include ConnectionHelper

      self.use_transactional_tests = false

      def setup
        @connection = ActiveRecord::Base.connection
      end


      def test_connection_error
        assert_raises ActiveRecord::ConnectionNotEstablished do
          ActiveRecord::Base.postgresql_connection(host: File::NULL)
        end
      end
    end
  end
end

