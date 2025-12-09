# frozen_string_literal: true

class Money
  module RatesStore # rubocop:disable Style/Documentation
    require 'money/rates_store/memory'

    # Custom exchange rate store with effective date support.
    #
    # This class extends Money::RatesStore::Memory to allow storing
    # exchange rates with an effective date. This enables storing and
    # retrieving historical rates for different dates.
    #
    # @example Basic usage
    #   store = Money::RatesStore::Fluence.new
    #   store.add_rate('EUR', 'USD', 1.12, effective_date: Date.today)
    #   store.get_rate('EUR', 'USD', effective_date: Date.today) # => 1.12
    #
    # @example Historical rates
    #   store.add_rate('EUR', 'USD', 1.10, effective_date: Date.new(2024, 1, 1))
    #   store.add_rate('EUR', 'USD', 1.15, effective_date: Date.new(2024, 6, 1))
    #   store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 1, 1)) # => 1.10
    #
    # @see Money::RatesStore::Memory
    class Fluence < Money::RatesStore::Memory
      # Initializes a new rate store.
      #
      # @param opts [Hash] Options passed to the parent class
      # @param rates [Hash] Initial rates hash (default: empty hash with default value)
      def initialize(opts = {}, rates = Hash.new { |h, k| h[k] = {} })
        super(opts, rates)
      end

      # Adds an exchange rate to the store for a given date.
      #
      # This operation is thread-safe through synchronization.
      #
      # @param currency_iso_from [String, Money::Currency] Source currency
      # @param currency_iso_to [String, Money::Currency] Target currency
      # @param rate [Numeric] Conversion rate
      # @param opts [Hash] Options
      # @option opts [Date] :effective_date Effective date for the rate (default: Date.today)
      # @return [Numeric] The stored rate
      def add_rate(currency_iso_from, currency_iso_to, rate, opts = {})
        guard.synchronize do
          effective_date = opts[:effective_date] || Date.today
          rates[rate_key_for(currency_iso_from, currency_iso_to)][effective_date] = rate
        end
      end

      # Retrieves an exchange rate from the store for a given date.
      #
      # This operation is thread-safe through synchronization.
      #
      # @param currency_iso_from [String, Money::Currency] Source currency
      # @param currency_iso_to [String, Money::Currency] Target currency
      # @param opts [Hash] Options
      # @option opts [Date] :effective_date Effective date for the rate (default: Date.today)
      # @return [Numeric, nil] The conversion rate or nil if not found
      def get_rate(currency_iso_from, currency_iso_to, opts = {})
        guard.synchronize do
          effective_date = opts[:effective_date] || Date.today
          rates[rate_key_for(currency_iso_from, currency_iso_to)][effective_date]
        end
      end

      # Iterates over all stored rates.
      #
      # @yield [from, to, rate, effective_date] Block called for each rate
      # @yieldparam from [String] ISO code of the source currency
      # @yieldparam to [String] ISO code of the target currency
      # @yieldparam rate [Numeric] Conversion rate
      # @yieldparam effective_date [Date] Effective date of the rate
      # @return [Enumerator] If no block is given
      def each_rate(&_block)
        return to_enum(:each_rate) unless block_given?

        guard.synchronize do
          rates.each do |key, rates|
            iso_from, iso_to = key.split(INDEX_KEY_SEPARATOR)
            rates.each do |effective_date, rate|
              yield iso_from, iso_to, rate, effective_date
            end
          end
        end
      end
    end
  end
end
