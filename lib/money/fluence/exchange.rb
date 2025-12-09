# frozen_string_literal: true

require_relative 'exchange/configuration'

class Money
  module Fluence
    # Main module for Fluence FX API integration with the Money gem.
    #
    # This module serves as the namespace for the Fluence exchange rate
    # functionality and provides configuration capabilities through
    # the {Configuration} module.
    #
    # @example Basic configuration
    #   Money::Fluence::Exchange.configure do |config|
    #     config.client_id = 'your_client_id'
    #     config.client_secret = 'your_client_secret'
    #   end
    #
    # @example Setting up the bank
    #   bank = Money::Bank::FluenceExchange.new(Money::RatesStore::Fluence.new)
    #   Money.default_bank = bank
    #
    # @see Money::Bank::FluenceExchange
    # @see Money::RatesStore::Fluence
    # @see Configuration
    module Exchange
      extend Configuration
    end
  end
end

require 'money/bank/fluence_exchange'
require 'money/rates_store/fluence'
