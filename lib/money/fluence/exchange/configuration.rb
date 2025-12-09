# frozen_string_literal: true

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
        def client_id
          @client_id || ENV['FX_CLIENT_ID']
        end

        def client_id=(value)
          @client_id = value
        end

        # @!attribute [rw] client_secret
        #   @return [String] OAuth client secret (default: ENV['FX_CLIENT_SECRET'])
        def client_secret
          @client_secret || ENV['FX_CLIENT_SECRET']
        end

        def client_secret=(value)
          @client_secret = value
        end

        # @!attribute [rw] base_url
        #   @return [String] Base URL for the Fluence FX API
        def base_url
          @base_url || 'https://fx.knowledge.appvision.fr'
        end

        def base_url=(value)
          @base_url = value
        end
      end
    end
  end
end
