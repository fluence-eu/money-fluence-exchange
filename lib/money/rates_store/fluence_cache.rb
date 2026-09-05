# frozen_string_literal: true

class Money
  module RatesStore
    # Exchange rate store keeping its rates in an ActiveSupport cache, +Rails.cache+ typically.
    #
    # A cache shared out of process frees every process of the rates it would otherwise hold.
    # The store needs only +read+ and +write+ from it, so the gem does not depend on ActiveSupport.
    # A cache does not list its keys, so +each_rate+ and the exports built on it are not supported,
    # and neither is +Marshal.dump+.
    #
    # @example
    #   store = Money::RatesStore::FluenceCache.new(Rails.cache)
    #   Money.default_bank = Money::Bank::FluenceExchange.new(store)
    #
    # @see Money::RatesStore::Fluence
    class FluenceCache
      # @param cache [#read, #write] Cache holding the rates
      def initialize(cache)
        @cache = cache
      end

      # @param currency_iso_from [String, Money::Currency] Source currency
      # @param currency_iso_to [String, Money::Currency] Target currency
      # @param rate [Numeric] Conversion rate
      # @param opts [Hash] Options
      # @option opts [Date] :effective_date Effective date for the rate (default: Date.today)
      # @return [Numeric] The stored rate
      def add_rate(currency_iso_from, currency_iso_to, rate, opts = {})
        cache.write(key_for(currency_iso_from, currency_iso_to, opts), rate)
        rate
      end

      # @param currency_iso_from [String, Money::Currency] Source currency
      # @param currency_iso_to [String, Money::Currency] Target currency
      # @param opts [Hash] Options
      # @option opts [Date] :effective_date Effective date for the rate (default: Date.today)
      # @return [Numeric, nil] The conversion rate or nil if not found
      def get_rate(currency_iso_from, currency_iso_to, opts = {})
        cache.read(key_for(currency_iso_from, currency_iso_to, opts))
      end

      # @raise [NotImplementedError] always
      def each_rate = raise(NotImplementedError, "#{self.class} cannot list its rates")

      # @raise [NotImplementedError] always
      def marshal_dump = raise(NotImplementedError, "#{self.class} cannot be marshaled: its rates live in the cache")

      def transaction = yield

      private

      attr_reader :cache

      def key_for(currency_iso_from, currency_iso_to, opts)
        pair = "#{currency_iso_from}_TO_#{currency_iso_to}".upcase
        "money-fluence-exchange/#{pair}/#{(opts[:effective_date] || Date.today).iso8601}"
      end
    end
  end
end
