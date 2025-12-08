# frozen_string_literal: true

class Money
  module Bank
    require 'money/bank/variable_exchange'

    class FluenceExchange < Money::Bank::VariableExchange
      require 'json'
      require 'net/https'

      RATE_FORMATS = [:json, :yaml].freeze

      attr_accessor :ttl_in_seconds
      attr_reader :rates_expire_at

      def initialize(*args, &block)
        super
        self.ttl_in_seconds = 3600 # 1 hour
      end

      def set_rate(from, to, rate, opts = {})
        from_currency = Money::Currency.wrap(from)
        to_currency = Money::Currency.wrap(to)
        opts[:effective_date] = Date.parse(opts[:effective_date].to_s) unless opts[:effective_date].is_a?(Date)

        store.add_rate(from_currency, to_currency, rate, **opts)
      end

      def get_rate(from, to, opts = {})
        from_currency = Money::Currency.wrap(from)
        to_currency = Money::Currency.wrap(to)
        opts[:effective_date] = Date.parse(opts[:effective_date].to_s) unless opts[:effective_date].is_a?(Date)

        rate = store.get_rate(from_currency, to_currency, **opts)
        return rate if rate

        rate, _effective_date = fetch_rate(from_currency, to_currency, **opts)
        store.add_rate(from_currency, to_currency, rate, **opts)
      end

      def exchange_with(from, to, opts = {}, &block)
        to_currency = Money::Currency.wrap(to)
        if from.currency == to_currency
          from
        elsif (rate = get_rate(from.currency, to, **opts))
          fractional = calculate_fractional(from, to_currency)
          from.dup_with(
            fractional: exchange(fractional, rate, &block),
            currency: to_currency,
            bank: self
          )
        else
          raise Money::UnknownRate, "No conversion rate known for '#{from.currency.iso_code}' -> '#{to_currency}'"
        end
      end

      def rates
        store.each_rate.each_with_object(Hash.new { |h, k| h[k] = {} }) do |(from, to, rate, effective_date), hash|
          hash[[from, to].join(SERIALIZER_SEPARATOR)][effective_date] = rate
        end
      end

      def import_rates(format, s, opts = {})
        raise Money::Bank::UnknownRateFormat unless RATE_FORMATS.include?(format)

        store.transaction do
          data = FORMAT_SERIALIZERS[format].load(s)

          data.each do |key, rates|
            from, to = key.split(SERIALIZER_SEPARATOR)
            rates.each do |effective_date, rate|
              store.add_rate(from, to, rate, effective_date: effective_date)
            end
          end
        end

        self
      end

      private

      FX_URL = 'https://fx.knowledge.appvision.fr'
      AUTH_URL = "#{FX_URL}/oauth/token".freeze

      def request_rate(from, to, opts = {})
        uri = URI.parse(FX_URL)
        uri.path = if opts[:effective_date]
                     "/v1/exchange_rates/#{from}/#{to}/#{opts[:effective_date]}"
                   else
                     "/v1/exchange_rates/#{from}/#{to}/latest"
                   end

        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{request_auth}"

        Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
          http.request(request)
        end
      end

      def extract_rate(data)
        payload = JSON.parse(data)
        [payload['rate'], Date.parse(payload['effective_date'])]
      end

      def fetch_rate(from, to, opts = {})
        response = request_rate(from.iso_code, to.iso_code, **opts)
        return unless response.is_a?(Net::HTTPSuccess)

        extract_rate(response.body)
      end

      def token_expired?
        @token_expires_at.nil? || Time.now >= @token_expires_at
      end

      def request_auth
        return @token if @token && !token_expired?
        return request_refresh if @refresh_token

        request_token('client_credentials')
      end

      def request_refresh
        request_token('refresh_token', @refresh_token)
      end

      def request_token(grant_type, refresh_token = nil)
        uri = URI.parse(AUTH_URL)
        request = Net::HTTP::Post.new(uri)
        params = { grant_type: grant_type, client_id: ENV.fetch('FX_CLIENT_ID'), client_secret: ENV.fetch('FX_CLIENT_SECRET') }
        params.merge!(refresh_token: refresh_token) if refresh_token
        request.set_form_data(params)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          @refresh_token = nil
          return auth
        end

        data = JSON.parse(response.body)
        @token = data['access_token']
        @refresh_token = data['refresh_token']
        @token_expires_at = Time.now + data['expires_in']

        @token
      end
    end
  end
end
