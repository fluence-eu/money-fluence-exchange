# frozen_string_literal: true

class Money
  module RatesStore
    require 'money/rates_store/memory'

    class Fluence < Money::RatesStore::Memory
      def initialize(opts = {}, rates = Hash.new { |h, k| h[k] = {} })
        super(opts, rates)
      end

      def add_rate(currency_iso_from, currency_iso_to, rate, opts = {})
        guard.synchronize do
          effective_date = opts[:effective_date] || Date.today
          rates[rate_key_for(currency_iso_from, currency_iso_to)][effective_date] = rate
        end
      end

      def get_rate(currency_iso_from, currency_iso_to, opts = {})
        guard.synchronize do
          effective_date = opts[:effective_date] || Date.today
          rates[rate_key_for(currency_iso_from, currency_iso_to)][effective_date]
        end
      end

      def each_rate(&block)
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
