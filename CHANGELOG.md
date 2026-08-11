## [Unreleased]

## [0.8.0] - 2026-08-11

### Changed

- **Breaking:** a rate request answered with a non-success status is no longer read as a missing rate. Only a `404` still returns nil — the service stating the pair has no rate on that date. A `401` or `403` raises `AuthenticationError`, every other status raises `ConnectionError`. A caller reading a nil rate as "this pair has no counterpart" would otherwise clear its converted amounts on an outage or a refused credential, silently and for every conversion asked
- **Breaking:** a token request reads its statuses the same way. A `401` or `403` still raises `AuthenticationError` (falling back to a full authentication first when a refresh token was refused), but every other status now raises `ConnectionError` instead — a token endpoint answering `503` is an outage that resolves itself, not credentials that never will, and a caller degrading on `ConnectionError` could not tell the two apart
- The message carried by an `AuthenticationError` on a token request names the status rather than quoting the response body. A caller matching on `"Error requesting token"` must match the status instead

## [0.7.0] - 2026-08-04

### Added

- `Money::Bank::FluenceExchange::ResponseError`, raised when the service answers something the bank cannot read. Distinct from `ConnectionError`: the service is reachable, so retrying the same request is unlikely to help

### Changed

- **Breaking:** an unreadable response body or `effective_date` now raises `ResponseError` instead of letting `JSON::ParserError` or `Date::Error` surface raw. A caller rescuing those must rescue `ResponseError` (or `Error`) instead — and no longer needs to know the payload is JSON

## [0.6.0] - 2026-08-04

### Added

- `Money::Bank::FluenceExchange::Error`, with `ConnectionError` and `AuthenticationError` subclasses, so a caller can tell a service it cannot reach from credentials it was refused — the first resolves itself, the second does not

### Changed

- **Breaking:** an authentication failure now raises `AuthenticationError` instead of a bare `RuntimeError`. A caller rescuing `RuntimeError` to catch it must rescue `AuthenticationError` (or `Error`) instead
- **Breaking:** transport failures (`SocketError`, `Errno::*`, `Net::OpenTimeout`, `Net::ReadTimeout`, `Net::ProtocolError`, `OpenSSL::SSL::SSLError`, `EOFError`) are translated into `ConnectionError` instead of surfacing raw. A caller enumerating those classes itself must rescue `ConnectionError` instead

## [0.5.0] - 2026-02-23

### Changed

- Update `money` dependency from `~> 6.19` to `~> 7.0`

## [0.4.2] - 2025-12-11

### Fixed

- Add missing gem entry point file `lib/money-fluence-exchange.rb` so the Extension module is properly loaded
- Use `prepend` instead of `include` for Extension module so methods correctly override Money's originals

## [0.4.1] - 2025-12-11

### Fixed

- Fix `set_rate` and `get_rate` methods to handle nil `effective_date` without error

## [0.4.0] - 2025-12-11

### Added

- Add `Money::Fluence::Exchange::Extension` module with enhanced Money instance methods
- Add `exchange_to` method with `effective_date` and `rounding_method` support
- Add `to_money` override with `effective_date` and `rounding_method` support
- Add `as_us_dollar`, `as_ca_dollar`, `as_euro` overrides with `effective_date` support
- Add dynamic `as_XXX` methods via `method_missing` for any currency (e.g., `as_gbp`, `as_jpy`, `as_chf`)
- Add `respond_to_missing?` for proper method introspection on dynamic `as_XXX` methods
- Add comprehensive test suite for `Extension` module (28 specs)

### Changed

- Use `bank` accessor instead of `@bank` instance variable for better encapsulation

## [0.3.0] - 2025-12-09

- Fix environment variables (`FX_CLIENT_ID`, `FX_CLIENT_SECRET`) now read dynamically at runtime instead of at module load time
- Remove `activesupport` dependency

## [0.2.0] - 2025-12-08

- Add `Money::Fluence::Exchange::Configuration` module for flexible configuration
- Support configuration via `configure` block or environment variables
- Add configurable `base_url` option
- Add `activesupport` dependency (>= 6.1)

## [0.1.0] - 2025-12-08

- Initial release
- Add `Money::Bank::FluenceExchange` bank with automatic rate fetching from Fluence FX API
- Add `Money::RatesStore::Fluence` rates store with effective date support
- Add OAuth2 authentication (client credentials flow) for FX API
- Support for historical exchange rates by effective date
- Import/export rates in JSON and YAML formats
