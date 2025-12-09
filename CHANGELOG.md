## [Unreleased]

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
