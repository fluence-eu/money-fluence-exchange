# Money Fluence Exchange

Exchange rate integration for the [Money](https://github.com/RubyMoney/money) gem, using the Fluence FX API.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'money-fluence-exchange', git: 'https://github.com/fluence-eu/money-fluence-exchange'
```

Then execute:

```bash
bundle install
```

## Configuration

Set the following environment variables for API authentication:

```bash
export FX_CLIENT_ID=your_client_id
export FX_CLIENT_SECRET=your_client_secret
```

## Usage

### Basic setup

```ruby
require 'money'
require 'money/bank/fluence_exchange'
require 'money/rates_store/fluence'

# Configure Money with Fluence bank and store
Money.default_bank = Money::Bank::FluenceExchange.new(Money::RatesStore::Fluence.new)
```

### Currency conversion

```ruby
# Convert using current exchange rate
Money.new(100_00, 'EUR').exchange_to('USD')

# Convert using a specific date's rate
Money.new(100_00, 'EUR').exchange_to('USD', effective_date: Date.new(2025, 1, 15))
```

### Manual rate management

```ruby
bank = Money.default_bank

# Set a rate manually
bank.set_rate('EUR', 'USD', 1.08, effective_date: Date.today)

# Get a rate
bank.get_rate('EUR', 'USD', effective_date: Date.today)
```

### Import/Export rates

```ruby
# Export rates to JSON
json_rates = bank.export_rates(:json)

# Import rates from JSON
bank.import_rates(:json, json_rates)
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
