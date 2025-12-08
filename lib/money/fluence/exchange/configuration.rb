# frozen_string_literal: true

require 'active_support/core_ext/module/attribute_accessors'

class Money
  module Fluence
    module Exchange
      module Configuration
        def configure
          yield self
        end

        mattr_accessor :client_id
        @@client_id = ENV['FX_CLIENT_ID']

        mattr_accessor :client_secret
        @@client_secret = ENV['FX_CLIENT_SECRET']

        mattr_accessor :base_url
        @@base_url = 'https://fx.knowledge.appvision.fr'
      end
    end
  end
end
