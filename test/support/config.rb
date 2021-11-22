# frozen_string_literal: true

require "active_support/configuration_file"

module ARTest
  class << self
    def config
      @config ||= read_config
    end

    private
      def read_config
        ActiveSupport::ConfigurationFile.parse(TEST_ROOT + "/config.yml")
      end
  end
end
