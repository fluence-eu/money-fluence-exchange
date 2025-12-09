# frozen_string_literal: true

class Money
  module Bank # rubocop:disable Style/Documentation
    require 'money/bank/variable_exchange'

    # Custom bank for the Money gem using the Fluence FX API.
    #
    # This class extends Money::Bank::VariableExchange to provide integration
    # with the Fluence FX API for automatic exchange rate retrieval.
    # Rates are cached locally and can be retrieved for specific dates
    # (historical rates) or for the current date.
    #
    # @example Basic setup and usage
    #   bank = Money::Bank::FluenceExchange.new(Money::RatesStore::Fluence.new)
    #   Money.default_bank = bank
    #
    #   # Automatic conversion with rate fetched from API
    #   Money.new(100, 'EUR').exchange_to('USD')
    #
    # @example Manually setting a rate
    #   bank.set_rate('EUR', 'USD', 1.12, effective_date: Date.today)
    #
    # @example Retrieving a historical rate
    #   bank.get_rate('EUR', 'USD', effective_date: Date.new(2024, 1, 15))
    #
    # @see Money::Bank::VariableExchange
    # @see Money::RatesStore::Fluence
    class FluenceExchange < Money::Bank::VariableExchange
      require 'json'
      require 'net/https'

      # Supported formats for rate import/export
      RATE_FORMATS = [:json, :yaml].freeze

      # @!attribute [rw] ttl_in_seconds
      #   @return [Integer] OAuth token cache TTL in seconds (default: 3600)
      attr_accessor :ttl_in_seconds

      # @!attribute [r] rates_expire_at
      #   @return [Time, nil] Expiration time for cached rates
      attr_reader :rates_expire_at

      # Initializes a new FluenceExchange instance.
      #
      # @param args Arguments passed to the parent class
      # @yield Optional block passed to the parent class
      def initialize(*args, &block)
        super
        self.ttl_in_seconds = 3600 # 1 hour
      end

      # Manually sets an exchange rate for a currency pair.
      #
      # @param from [String, Symbol, Money::Currency] Source currency
      # @param to [String, Symbol, Money::Currency] Target currency
      # @param rate [Numeric] Conversion rate
      # @param opts [Hash] Additional options
      # @option opts [Date, String] :effective_date Effective date for the rate (default: today)
      # @return [Numeric] The stored rate
      def set_rate(from, to, rate, opts = {})
        from_currency = Money::Currency.wrap(from)
        to_currency = Money::Currency.wrap(to)
        opts[:effective_date] = Date.parse(opts[:effective_date].to_s) unless opts[:effective_date].is_a?(Date)

        store.add_rate(from_currency, to_currency, rate, **opts)
      end

      # Retrieves the exchange rate for a currency pair.
      #
      # If the rate is not cached, it is automatically fetched from the
      # Fluence FX API and cached for future requests.
      #
      # @param from [String, Symbol, Money::Currency] Source currency
      # @param to [String, Symbol, Money::Currency] Target currency
      # @param opts [Hash] Additional options
      # @option opts [Date, String] :effective_date Date for which to retrieve the rate
      # @return [Numeric, nil] The conversion rate or nil if not found
      def get_rate(from, to, opts = {})
        from_currency = Money::Currency.wrap(from)
        to_currency = Money::Currency.wrap(to)
        opts[:effective_date] = Date.parse(opts[:effective_date].to_s) unless opts[:effective_date].is_a?(Date)

        rate = store.get_rate(from_currency, to_currency, **opts)
        return rate if rate

        rate, _effective_date = fetch_rate(from_currency, to_currency, **opts)
        store.add_rate(from_currency, to_currency, rate, **opts)
      end

      # Converts a Money object to another currency.
      #
      # @param from [Money] Source amount to convert
      # @param to [String, Symbol, Money::Currency] Target currency
      # @param opts [Hash] Additional options
      # @option opts [Date, String] :effective_date Date of the rate to use
      # @yield Optional block to customize the calculation
      # @return [Money] New amount in the target currency
      # @raise [Money::UnknownRate] If no rate is available for the conversion
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

      # Returns all stored rates as a nested hash.
      #
      # @return [Hash] Hash in the form { "EUR_TO_USD" => { Date => rate } }
      def rates
        store.each_rate.each_with_object(Hash.new { |h, k| h[k] = {} }) do |(from, to, rate, effective_date), hash|
          hash[[from, to].join(SERIALIZER_SEPARATOR)][effective_date] = rate
        end
      end

      # Imports rates from a JSON or YAML string.
      #
      # @param format [Symbol] Data format (:json or :yaml)
      # @param s [String] String containing rates to import
      # @param opts [Hash] Additional options (currently unused)
      # @return [self] The current instance for chaining
      # @raise [Money::Bank::UnknownRateFormat] If the format is not supported
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

      # Base URL for the Fluence FX API
      FX_URL = Money::Fluence::Exchange.base_url

      # OAuth authentication URL
      AUTH_URL = "#{FX_URL}/oauth/token".freeze

      # Performs an HTTP request to fetch a rate from the API.
      #
      # @param from [String] ISO code of the source currency
      # @param to [String] ISO code of the target currency
      # @param opts [Hash] Options
      # @option opts [Date] :effective_date Date of the rate (uses 'latest' if absent)
      # @return [Net::HTTPResponse] HTTP response from the API
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

      # Extracts the rate and effective date from the API JSON response.
      #
      # @param data [String] JSON response body
      # @return [Array<(Numeric, Date)>] Tuple [rate, effective_date]
      def extract_rate(data)
        payload = JSON.parse(data)
        [payload['rate'], Date.parse(payload['effective_date'])]
      end

      # Fetches a rate from the API and parses it.
      #
      # @param from [Money::Currency] Source currency
      # @param to [Money::Currency] Target currency
      # @param opts [Hash] Options passed to request_rate
      # @return [Array<(Numeric, Date)>, nil] Tuple [rate, effective_date] or nil on error
      def fetch_rate(from, to, opts = {})
        response = request_rate(from.iso_code, to.iso_code, **opts)
        return unless response.is_a?(Net::HTTPSuccess)

        extract_rate(response.body)
      end

      # Checks if the OAuth token has expired.
      #
      # @return [Boolean] true if the token is expired or non-existent
      def token_expired?
        @token_expires_at.nil? || Time.now >= @token_expires_at
      end

      # Handles OAuth authentication with automatic refresh.
      #
      # Returns the cached token if valid, attempts a refresh if possible,
      # or performs a full authentication.
      #
      # @return [String] Valid OAuth access token
      def request_auth
        return @token if @token && !token_expired?
        return request_refresh if @refresh_token

        request_token('client_credentials')
      end

      # Attempts to refresh the OAuth token using the refresh_token.
      #
      # @return [String] New access token
      def request_refresh
        request_token('refresh_token', @refresh_token)
      end

      # Performs an OAuth authentication request.
      #
      # On failure with a refresh_token, resets and retries
      # with full authentication.
      #
      # @param grant_type [String] OAuth grant type ('client_credentials' or 'refresh_token')
      # @param refresh_token [String, nil] Refresh token for 'refresh_token' grant_type
      # @return [String] OAuth access token
      # @raise [RuntimeError] If authentication fails
      def request_token(grant_type, refresh_token = nil)
        uri = URI.parse(AUTH_URL)
        request = Net::HTTP::Post.new(uri)
        params = {
          grant_type: grant_type,
          client_id: Money::Fluence::Exchange.client_id,
          client_secret: Money::Fluence::Exchange.client_secret
        }
        params.merge!(refresh_token: refresh_token) if refresh_token
        request.set_form_data(params)

        response = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          @refresh_token = nil
          return request_auth if grant_type == 'refresh_token'

          raise "Error requesting token: #{response.body}"
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
