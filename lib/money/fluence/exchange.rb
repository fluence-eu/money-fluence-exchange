# frozen_string_literal: true

require_relative 'exchange/configuration'

class Money
  module Fluence
    # Main module for Fluence FX API integration with the Money gem.
    #
    # This module serves as the namespace for the Fluence exchange rate
    # functionality and provides:
    # - Configuration capabilities through the {Configuration} module
    # - Money instance methods through the {Extension} module
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
    # @example Converting currencies with historical rates
    #   money = Money.new(1000, 'EUR')
    #   money.exchange_to('USD', effective_date: Date.new(2024, 1, 15))
    #
    # @example Using dynamic currency conversion
    #   Money.new(1000, 'EUR').as_gbp
    #   Money.new(1000, 'USD').as_jpy(effective_date: Date.today - 30)
    #
    # @see Money::Bank::FluenceExchange The custom bank for API interaction
    # @see Money::RatesStore::Fluence The rates store with date support
    # @see Configuration Configuration options (client_id, client_secret, base_url)
    # @see Extension Money instance methods (exchange_to, as_XXX, etc.)
    module Exchange
      extend Configuration

      # Extension module that adds enhanced currency exchange capabilities to Money objects.
      #
      # This module is automatically included into the Money class when the gem is loaded,
      # providing enhanced currency conversion methods with support for:
      # - Historical exchange rates via the +effective_date+ option
      # - Custom rounding behavior via block parameter
      # - Dynamic currency conversion via +as_XXX+ methods
      #
      # @note This module overrides +to_money+, +as_us_dollar+, +as_ca_dollar+, and +as_euro+
      #   from the Money gem to add +effective_date+ support.
      #
      # @example Convert to another currency using the latest rate
      #   money = Money.new(1000, 'EUR')
      #   money.exchange_to('USD')
      #
      # @example Convert using a historical rate
      #   money = Money.new(1000, 'EUR')
      #   money.exchange_to('USD', effective_date: Date.new(2024, 1, 15))
      #
      # @example With custom rounding
      #   money = Money.new(1000, 'EUR')
      #   money.exchange_to('USD') { |n| n.round(0, :banker) }
      #
      # @example Dynamic currency conversion (any currency)
      #   Money.new(1000, 'EUR').as_gbp
      #   Money.new(1000, 'EUR').as_jpy
      #   Money.new(1000, 'EUR').as_chf(effective_date: Date.yesterday)
      #
      # @see #exchange_to Main conversion method
      # @see #to_money Conversion with optional currency
      # @see #method_missing Dynamic as_XXX handler
      # @see Money::Bank::FluenceExchange#exchange_with Bank conversion method
      module Extension
        # Converts the Money object to the given currency, or returns self if no conversion needed.
        #
        # This method overrides the default +to_money+ behavior to add support for
        # the +effective_date+ option, enabling historical exchange rate lookups.
        #
        # @param given_currency [Money::Currency, String, Symbol, nil] the target currency.
        #   If +nil+, returns self unchanged.
        # @param opts [Hash] additional options
        # @option opts [Date] :effective_date the date for which to fetch the exchange rate.
        #   Defaults to today's date if not specified.
        # @param rounding_method [Proc] optional block for custom rounding behavior
        #
        # @return [Money] a new Money object in the target currency
        # @return [self] if +given_currency+ is +nil+ or matches the current currency
        #
        # @example Convert to USD
        #   Money.new(1000, 'EUR').to_money('USD')
        #
        # @example No conversion when currency matches
        #   Money.new(1000, 'EUR').to_money('EUR')
        #   # => returns self
        #
        # @example With historical rate
        #   Money.new(1000, 'EUR').to_money('USD', effective_date: Date.new(2024, 1, 15))
        #
        # @example With custom rounding
        #   Money.new(1000, 'EUR').to_money('USD') { |n| n.round(0, :banker) }
        #
        def to_money(given_currency = nil, opts = {}, &rounding_method)
          given_currency = Currency.wrap(given_currency)

          return self if given_currency.nil? || currency == given_currency

          exchange_to(given_currency, **opts, &rounding_method)
        end

        # Converts the Money object to another currency.
        #
        # This method wraps the bank's +exchange_with+ method, adding support
        # for the +effective_date+ option to retrieve historical exchange rates
        # from the Fluence FX API.
        #
        # @param other_currency [Money::Currency, String, Symbol] the target currency
        # @param opts [Hash] additional options
        # @option opts [Date] :effective_date the date for which to fetch the exchange rate.
        #   Defaults to today's date if not specified.
        # @param rounding_method [Proc] optional block for custom rounding behavior
        #
        # @return [Money] a new Money object in the target currency
        # @return [self] if the target currency is the same as the current currency
        #
        # @raise [Money::Bank::UnknownRate] if the exchange rate cannot be found or fetched
        #
        # @example Basic conversion
        #   Money.new(100_00, 'EUR').exchange_to('USD')
        #   # => #<Money @cents=108_50 @currency="USD">
        #
        # @example Historical conversion
        #   Money.new(100_00, 'EUR').exchange_to('USD', effective_date: Date.new(2024, 6, 1))
        #
        def exchange_to(other_currency, opts = {}, &rounding_method)
          other_currency = Currency.wrap(other_currency)

          return self if currency == other_currency

          bank.exchange_with(self, other_currency, **opts, &rounding_method)
        end

        # Converts the Money object to US Dollars (USD).
        #
        # Overrides the default Money method to add support for +effective_date+.
        #
        # @param opts [Hash] additional options
        # @option opts [Date] :effective_date the date for which to fetch the exchange rate
        # @param rounding_method [Proc] optional block for custom rounding behavior
        #
        # @return [Money] a new Money object in USD
        #
        # @example
        #   Money.new(1000, 'EUR').as_us_dollar
        #
        # @example With custom rounding
        #   Money.new(1000, 'EUR').as_us_dollar { |n| n.round(0, :banker) }
        #
        def as_us_dollar(opts = {}, &rounding_method)
          exchange_to('USD', **opts, &rounding_method)
        end

        # Converts the Money object to Canadian Dollars (CAD).
        #
        # Overrides the default Money method to add support for +effective_date+.
        #
        # @param opts [Hash] additional options
        # @option opts [Date] :effective_date the date for which to fetch the exchange rate
        # @param rounding_method [Proc] optional block for custom rounding behavior
        #
        # @return [Money] a new Money object in CAD
        #
        # @example
        #   Money.new(1000, 'USD').as_ca_dollar
        #
        # @example With custom rounding
        #   Money.new(1000, 'USD').as_ca_dollar { |n| n.round(0, :banker) }
        #
        def as_ca_dollar(opts = {}, &rounding_method)
          exchange_to('CAD', **opts, &rounding_method)
        end

        # Converts the Money object to Euros (EUR).
        #
        # Overrides the default Money method to add support for +effective_date+.
        #
        # @param opts [Hash] additional options
        # @option opts [Date] :effective_date the date for which to fetch the exchange rate
        # @param rounding_method [Proc] optional block for custom rounding behavior
        #
        # @return [Money] a new Money object in EUR
        #
        # @example
        #   Money.new(1000, 'USD').as_euro
        #
        # @example With custom rounding
        #   Money.new(1000, 'USD').as_euro { |n| n.round(0, :banker) }
        #
        def as_euro(opts = {}, &rounding_method)
          exchange_to('EUR', **opts, &rounding_method)
        end

        # Dynamically handles +as_XXX+ methods to convert to any currency.
        #
        # Supports two naming conventions:
        # - ISO code: +as_usd+, +as_eur+, +as_gbp+, +as_jpy+, etc.
        # - Full name: +as_british_pound+, +as_japanese_yen+, etc.
        #
        # @param method [Symbol] the method name (e.g., +:as_gbp+, +:as_jpy+)
        # @param args [Array] optional arguments, first element can be options hash
        # @param block [Proc] optional rounding method
        #
        # @return [Money] a new Money object in the target currency
        #
        # @raise [NoMethodError] if the method doesn't match +as_XXX+ pattern
        #   or the currency is not recognized
        #
        # @example Using ISO codes
        #   Money.new(1000, 'EUR').as_gbp
        #   Money.new(1000, 'USD').as_jpy
        #   Money.new(1000, 'USD').as_chf
        #
        # @example With options and rounding
        #   Money.new(1000, 'EUR').as_gbp(effective_date: Date.new(2024, 1, 15))
        #   Money.new(1000, 'EUR').as_gbp { |n| n.round(0, :banker) }
        #
        def method_missing(method, *args, &block)
          return super unless method.to_s.start_with?('as_')

          currency_key = method.to_s.sub('as_', '')
          currency = Currency.find(currency_key)

          return super if currency.nil?

          exchange_to(currency, **args.first || {}, &block)
        end

        # Indicates whether the object responds to +as_XXX+ methods.
        #
        # @param method [Symbol] the method name to check
        # @param include_private [Boolean] whether to include private methods
        #
        # @return [Boolean] true if the method matches +as_XXX+ and the currency exists
        #
        def respond_to_missing?(method, include_private = false)
          return super unless method.to_s.start_with?('as_')

          currency_key = method.to_s.sub('as_', '')
          Currency.find(currency_key) ? true : super
        end
      end
    end
  end
end

require 'money/bank/fluence_exchange'
require 'money/rates_store/fluence'

Money.prepend Money::Fluence::Exchange::Extension
