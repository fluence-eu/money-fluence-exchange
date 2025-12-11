## [Unreleased]

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
