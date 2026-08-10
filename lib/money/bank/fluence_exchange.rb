# frozen_string_literal: true

class Money
  module Bank # rubocop:disable Style/Documentation
    require 'money/bank/base'
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
      require 'date'
      require 'json'
      require 'net/https'
      require 'uri'
      require 'yaml'

      # Supported formats for rate import/export
      RATE_FORMATS = %i[json yaml].freeze
      FORMAT_SERIALIZERS = { json: JSON, yaml: YAML }.freeze

      # Base class for every failure this bank raises on its own behalf, so a caller can catch
      # the whole family without listing transport internals.
      Error = Class.new(StandardError)

      # The FX service could not be reached, or dropped the connection. Says nothing about the
      # currencies asked for: the rate is merely unavailable, and a later attempt may succeed.
      ConnectionError = Class.new(Error)

      # The FX service refused the credentials. Unlike a ConnectionError this does not resolve
      # itself — every conversion will fail until it is addressed — so callers should let it
      # surface rather than degrade.
      AuthenticationError = Class.new(Error)

      # The FX service answered, but not in a form this bank can read. Distinct from a
      # ConnectionError: the service is reachable, so retrying the same request is unlikely to
      # help. Callers should not have to know the payload is JSON, nor rescue JSON::ParserError
      # on this bank's behalf.
      ResponseError = Class.new(Error)

      # The transport failures Net::HTTP surfaces, translated into {ConnectionError}. Without
      # this a caller has to know that a refused socket, an expired TLS handshake and a read
      # timeout are all the same thing to it.
      TRANSPORT_ERRORS = [SocketError, IOError, SystemCallError, Net::OpenTimeout,
                          Net::ReadTimeout, Net::ProtocolError, OpenSSL::SSL::SSLError].freeze

      # Manually sets an exchange rate for a currency pair.
      #
      # @param from [String, Symbol, Money::Currency] Source currency
      # @param to [String, Symbol, Money::Currency] Target currency
      # @param rate [Numeric] Conversion rate
      # @param opts [Hash] Additional options
      # @option opts [Date, String] :effective_date Effective date for the rate (default: today)
      # @return [Numeric] The stored rate
      def set_rate(from, to, rate, opts = {})
        from_currency, to_currency, opts = normalize(from, to, opts)

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
        from_currency, to_currency, opts = normalize(from, to, opts)

        rate = store.get_rate(from_currency, to_currency, **opts)
        return rate unless rate.nil?
        return nil if absence_settled?(from_currency, to_currency, opts)

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
          raise Money::Bank::UnknownRate, "No conversion rate known for '#{from.currency.iso_code}' -> '#{to_currency}'"
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
      def import_rates(format, data_string, _opts = {})
        raise Money::Bank::UnknownRateFormat unless RATE_FORMATS.include?(format)

        store.transaction do
          data = FORMAT_SERIALIZERS[format].load(data_string)

          data.each do |key, rates|
            from, to = key.split(SERIALIZER_SEPARATOR)
            rates.each do |effective_date, rate|
              effective_date = Date.parse(effective_date.to_s) unless effective_date.is_a?(Date)
              store.add_rate(from, to, rate, effective_date: effective_date)
            end
          end
        end

        self
      end

      private

      # +from+ and +to+ as currencies, and +opts+ carrying its +effective_date+ as a Date, so the
      # store is only ever asked in the terms it holds them. Callers pass ISO strings, symbols and
      # dates written as strings, indifferently.
      #
      # @return [Array<(Money::Currency, Money::Currency, Hash)>]
      def normalize(from, to, opts)
        date = opts[:effective_date]
        opts = opts.merge(effective_date: Date.parse(date.to_s)) if date && !date.is_a?(Date)

        [Money::Currency.wrap(from), Money::Currency.wrap(to), opts]
      end

      # Whether the store holding no rate for this pair and date means the service was asked and
      # said there is none, rather than that nobody has asked yet. Settles only for a date already
      # past: a rate the service does not have at 9am may be published by noon, and this store
      # lives as long as the process — an absence taken as settled on today would hold for the
      # rest of the day. A request carrying no date asks for the latest, which is today.
      #
      # @return [Boolean]
      def absence_settled?(from, to, opts)
        date = opts[:effective_date]
        !date.nil? && date < Date.today && store.rate_known?(from, to, **opts)
      end

      # Base URL for the Fluence FX API
      FX_URL = Money::Fluence::Exchange.base_url

      # OAuth authentication URL
      AUTH_URL = "#{FX_URL}/oauth/token".freeze

      # Executes an authenticated HTTP GET request.
      #
      # @param uri [URI] The URI to send the request to
      # @return [Net::HTTPResponse] The HTTP response
      # @raise [ConnectionError] If the service cannot be reached
      def execute_http_get_request(uri)
        request = Net::HTTP::Get.new(uri)
        request['Authorization'] = "Bearer #{request_auth}"

        with_connection_errors do
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.is_a?(URI::HTTPS)) do |http|
            http.request(request)
          end
        end
      end

      # Extracts the rate and effective date from the API JSON response.
      #
      # @param data [String] JSON response body
      # @return [Array<(Numeric, Date)>] Tuple [rate, effective_date]
      # @raise [ResponseError] If the body cannot be read
      def extract_rate(data)
        with_response_errors do
          payload = JSON.parse(data)
          [payload['rate'], Date.parse(payload['effective_date'])]
        end
      end

      # Runs +block+, translating a response this bank cannot parse into {ResponseError}.
      #
      # @return [Object] whatever the block returns
      # @raise [ResponseError] If the response cannot be read
      def with_response_errors
        yield
      rescue JSON::ParserError, Date::Error, TypeError => e
        raise ResponseError, "#{e.class}: #{e.message}"
      end

      # Fetches a rate from the API and parses it.
      #
      # @param from [Money::Currency] Source currency
      # @param to [Money::Currency] Target currency
      # @param opts [Hash] Options passed to request_rate
      # @return [Array<(Numeric, Date)>, nil] Tuple [rate, effective_date], or nil when the
      #   service states the pair has no rate on that date
      # @raise [AuthenticationError] If the service refused the request
      # @raise [ConnectionError] If the service failed to answer
      def fetch_rate(from, to, opts = {})
        from_iso_code = from.iso_code
        to_iso_code = to.iso_code
        uri = URI.parse(FX_URL)
        uri.path = if opts[:effective_date]
                     "/v1/exchange_rates/#{from_iso_code}/#{to_iso_code}/#{opts[:effective_date]}"
                   else
                     "/v1/exchange_rates/#{from_iso_code}/#{to_iso_code}/latest"
                   end

        rate_from(execute_http_get_request(uri))
      end

      # The rate +response+ carries, or nil when the service states the pair has none on that
      # date — a 404, and the only answer a caller may read as "no rate". Every other non-success
      # is raised as its own kind: read as nil they would all become a pair with no counterpart,
      # so an outage or a refused credential would pass for a rate that legitimately does not
      # exist — silently, and for every conversion asked.
      #
      # @param response [Net::HTTPResponse] The service's answer
      # @return [Array<(Numeric, Date)>, nil] Tuple [rate, effective_date], or nil on a 404
      # @raise [AuthenticationError] If the service refused the request
      # @raise [ConnectionError] If the service failed to answer
      def rate_from(response)
        case response
        when Net::HTTPSuccess then extract_rate(response.body)
        when Net::HTTPNotFound then nil
        else raise failure_for(response, 'Rate request')
        end
      end

      # The error an answer that is not the one asked for deserves. Both requests this bank makes
      # classify their failures the same way and differ only in what they were asking for: a 401
      # and a 403 say the credentials were refused, which no retry resolves, where every other
      # status is the service failing to answer — which does resolve itself.
      #
      # @param response [Net::HTTPResponse] The service's answer
      # @param request [String] What was asked for, as the message names it
      # @return [Error] The error to raise, unraised
      def failure_for(response, request)
        case response
        when Net::HTTPUnauthorized, Net::HTTPForbidden
          AuthenticationError.new("#{request} refused: #{response.code}")
        else
          ConnectionError.new("#{request} failed: #{response.code}")
        end
      end

      # Checks if the OAuth token has expired.
      #
      # @return [Boolean] true if the token is expired or non-existent
      def token_expired?
        @token_expires_at.nil? || Time.now >= @token_expires_at
      end

      # Builds the parameters hash for OAuth token requests.
      #
      # @param grant_type [String] OAuth grant type ('client_credentials' or 'refresh_token')
      # @param refresh_token [String, nil] Refresh token for 'refresh_token' grant type
      # @return [Hash] Parameters hash for the token request
      def build_token_params(grant_type, refresh_token)
        params = {
          grant_type: grant_type,
          client_id: Money::Fluence::Exchange.client_id,
          client_secret: Money::Fluence::Exchange.client_secret
        }
        params[:refresh_token] = refresh_token if refresh_token
        params
      end

      # Executes an HTTP POST request with form data.
      #
      # @param uri [URI] The URI to send the request to
      # @param params [Hash] Form parameters to send
      # @return [Net::HTTPResponse] The HTTP response
      # @raise [ConnectionError] If the service cannot be reached
      def execute_http_post_request(uri, params)
        request = Net::HTTP::Post.new(uri)
        request.set_form_data(params)

        with_connection_errors do
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https') do |http|
            http.request(request)
          end
        end
      end

      # Runs +block+, translating every transport failure into {ConnectionError}.
      #
      # @return [Object] whatever the block returns
      # @raise [ConnectionError] If the service cannot be reached
      def with_connection_errors
        yield
      rescue *TRANSPORT_ERRORS => e
        raise ConnectionError, "#{e.class}: #{e.message}"
      end

      # Performs an OAuth authentication request.
      #
      # Statuses are read the same way a rate request reads them (see {#rate_from}): only a
      # refusal is a credential problem. A token request answered 503 used to raise
      # AuthenticationError too, which a caller cannot degrade on — it would treat an outage
      # that resolves itself as credentials that never will.
      #
      # @param grant_type [String] OAuth grant type ('client_credentials' or 'refresh_token')
      # @param refresh_token [String, nil] Refresh token for 'refresh_token' grant_type
      # @return [String] OAuth access token
      # @raise [AuthenticationError] If the service refused the credentials
      # @raise [ConnectionError] If the service failed to answer
      def request_token(grant_type, refresh_token = nil)
        uri = URI.parse(AUTH_URL)
        params = build_token_params(grant_type, refresh_token)
        response = execute_http_post_request(uri, params)

        return store_token(with_response_errors { JSON.parse(response.body) }) if response.is_a?(Net::HTTPSuccess)

        failure = failure_for(response, 'Token request')
        return retry_in_full if failure.is_a?(AuthenticationError) && grant_type == 'refresh_token'

        raise failure
      end

      # Authenticates from the credentials themselves, the refresh token having been refused —
      # which is what an expired one looks like. Dropping it first is what stops {#request_auth}
      # from coming straight back here, and only a refusal is worth this second request:
      # re-authenticating around an outage spends it on the same failure.
      #
      # @return [String] OAuth access token
      def retry_in_full
        @refresh_token = nil
        request_auth
      end

      # Caches the access token, its refresh token and its expiry.
      #
      # @param data [Hash] Parsed authentication payload
      # @return [String] OAuth access token
      def store_token(data)
        @token = data['access_token']
        @refresh_token = data['refresh_token']
        @token_expires_at = Time.now + data['expires_in']

        @token
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
    end
  end
end
