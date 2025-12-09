# frozen_string_literal: true

require 'active_support/core_ext/module/attribute_accessors'

class Money
  module Fluence
    module Exchange
      # Configuration module for Fluence FX API integration.
      #
      # This module provides the configuration settings required for
      # OAuth authentication and connection to the Fluence FX API.
      # It is mixed into Money::Fluence::Exchange.
      #
      # Default values are read from environment variables,
      # but can be overridden via the configuration block.
      #
      # @example Configuration via block
      #   Money::Fluence::Exchange.configure do |config|
      #     config.client_id = 'your_client_id'
      #     config.client_secret = 'your_client_secret'
      #     config.base_url = 'https://custom-api.example.com'
      #   end
      #
      # @example Configuration via environment variables
      #   # Set FX_CLIENT_ID and FX_CLIENT_SECRET in the environment
      #   # Values will be automatically used
      #
      module Configuration
        # Configures the module with a block.
        #
        # @yield [self] The Configuration module for setting parameters
        # @return [void]
        def configure
          yield self
        end

        # @!attribute [rw] client_id
        #   @return [String] OAuth client ID (default: ENV['FX_CLIENT_ID'])
        mattr_accessor :client_id
        @@client_id = ENV['FX_CLIENT_ID']

        # @!attribute [rw] client_secret
        #   @return [String] OAuth client secret (default: ENV['FX_CLIENT_SECRET'])
        mattr_accessor :client_secret
        @@client_secret = ENV['FX_CLIENT_SECRET']

        # @!attribute [rw] base_url
        #   @return [String] Base URL for the Fluence FX API
        mattr_accessor :base_url
        @@base_url = 'https://fx.knowledge.appvision.fr'
      end
    end
  end
end
