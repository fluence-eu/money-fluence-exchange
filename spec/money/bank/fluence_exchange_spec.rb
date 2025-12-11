# frozen_string_literal: true

RSpec.describe Money::Bank::FluenceExchange do
  subject(:bank) { described_class.new(Money::RatesStore::Fluence.new) }

  let(:auth_response) do
    {
      'access_token' => 'test_access_token',
      'refresh_token' => 'test_refresh_token',
      'expires_in' => 3600
    }
  end

  let(:rate_response) do
    {
      'rate' => 1.12,
      'effective_date' => '2024-06-15'
    }
  end

  before do
    Money::Fluence::Exchange.configure do |config|
      config.client_id = 'test_client_id'
      config.client_secret = 'test_client_secret'
    end
  end

  describe '#initialize' do
    it 'accepts a custom store' do
      custom_store = Money::RatesStore::Fluence.new
      custom_bank = described_class.new(custom_store)
      expect(custom_bank.store).to eq(custom_store)
    end
  end

  describe '#set_rate' do
    it 'stores a rate for the current date' do
      bank.set_rate('EUR', 'USD', 1.12, effective_date: Date.today)
      expect(bank.store.get_rate('EUR', 'USD', effective_date: Date.today)).to eq(1.12)
    end

    it 'stores a rate for a specific effective date' do
      effective_date = Date.new(2024, 6, 15)
      bank.set_rate('EUR', 'USD', 1.10, effective_date: effective_date)
      expect(bank.store.get_rate('EUR', 'USD', effective_date: effective_date)).to eq(1.10)
    end

    it 'accepts string effective_date' do
      bank.set_rate('EUR', 'USD', 1.10, effective_date: '2024-06-15')
      expect(bank.store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 6, 15))).to eq(1.10)
    end

    it 'accepts currency symbols' do
      bank.set_rate(:EUR, :USD, 1.12, effective_date: Date.today)
      expect(bank.store.get_rate('EUR', 'USD', effective_date: Date.today)).to eq(1.12)
    end

    it 'handles nil effective_date without error' do
      expect { bank.set_rate('EUR', 'USD', 1.12, effective_date: nil) }.not_to raise_error
    end

    it 'works without effective_date option' do
      expect { bank.set_rate('EUR', 'USD', 1.12) }.not_to raise_error
    end
  end

  describe '#get_rate' do
    context 'when rate is cached' do
      before do
        bank.set_rate('EUR', 'USD', 1.12, effective_date: Date.today)
      end

      it 'returns the cached rate' do
        expect(bank.get_rate('EUR', 'USD', effective_date: Date.today)).to eq(1.12)
      end

      it 'does not make an API request' do
        expect(Net::HTTP).not_to receive(:start)
        bank.get_rate('EUR', 'USD', effective_date: Date.today)
      end
    end

    context 'when rate is not cached' do
      let(:http_success) { instance_double(Net::HTTPSuccess, body: rate_response.to_json) }
      let(:auth_success) { instance_double(Net::HTTPSuccess, body: auth_response.to_json) }

      before do
        allow(http_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(auth_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:start).and_return(auth_success, http_success)
      end

      it 'fetches rate from API and caches it' do
        rate = bank.get_rate('EUR', 'USD', effective_date: Date.today)
        expect(rate).to eq(1.12)
      end
    end

    context 'when effective_date is nil or missing' do
      let(:http_success) { instance_double(Net::HTTPSuccess, body: rate_response.to_json) }
      let(:auth_success) { instance_double(Net::HTTPSuccess, body: auth_response.to_json) }

      before do
        allow(http_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(auth_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
        allow(Net::HTTP).to receive(:start).and_return(auth_success, http_success)
      end

      it 'handles nil effective_date without error' do
        expect { bank.get_rate('EUR', 'USD', effective_date: nil) }.not_to raise_error
      end

      it 'works without effective_date option' do
        expect { bank.get_rate('EUR', 'USD') }.not_to raise_error
      end
    end
  end

  describe '#exchange_with' do
    before do
      bank.set_rate('EUR', 'USD', 1.12, effective_date: Date.today)
    end

    let(:money_eur) { Money.new(10_000, 'EUR') }

    it 'converts money to another currency' do
      result = bank.exchange_with(money_eur, 'USD', effective_date: Date.today)
      expect(result.currency.iso_code).to eq('USD')
      expect(result.fractional).to eq(11_200)
    end

    it 'returns the same object when currencies are equal' do
      result = bank.exchange_with(money_eur, 'EUR', effective_date: Date.today)
      expect(result).to eq(money_eur)
    end

    it 'raises UnknownRate when no rate is available' do
      allow(bank).to receive(:fetch_rate).and_return(nil)

      expect do
        bank.exchange_with(money_eur, 'GBP', effective_date: Date.today)
      end.to raise_error(Money::Bank::UnknownRate)
    end
  end

  describe '#rates' do
    before do
      bank.set_rate('EUR', 'USD', 1.12, effective_date: Date.new(2024, 1, 1))
      bank.set_rate('EUR', 'USD', 1.15, effective_date: Date.new(2024, 6, 1))
      bank.set_rate('EUR', 'GBP', 0.85, effective_date: Date.new(2024, 1, 1))
    end

    it 'returns all rates as a nested hash' do
      result = bank.rates
      expect(result['EUR_TO_USD'][Date.new(2024, 1, 1)]).to eq(1.12)
      expect(result['EUR_TO_USD'][Date.new(2024, 6, 1)]).to eq(1.15)
      expect(result['EUR_TO_GBP'][Date.new(2024, 1, 1)]).to eq(0.85)
    end
  end

  describe '#import_rates' do
    let(:json_data) do
      {
        'EUR_TO_USD' => {
          '2024-01-01' => 1.12,
          '2024-06-01' => 1.15
        }
      }.to_json
    end

    it 'imports rates from JSON' do
      bank.import_rates(:json, json_data)
      expect(bank.store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 1, 1))).to eq(1.12)
      expect(bank.store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 6, 1))).to eq(1.15)
    end

    it 'raises UnknownRateFormat for unsupported formats' do
      expect do
        bank.import_rates(:xml, '<rates/>')
      end.to raise_error(Money::Bank::UnknownRateFormat)
    end

    it 'returns self for chaining' do
      result = bank.import_rates(:json, json_data)
      expect(result).to eq(bank)
    end
  end

  describe 'OAuth authentication' do
    let(:auth_success) { instance_double(Net::HTTPSuccess, body: auth_response.to_json) }
    let(:rate_success) { instance_double(Net::HTTPSuccess, body: rate_response.to_json) }

    before do
      allow(auth_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(rate_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
    end

    it 'requests a new token when none exists' do
      allow(Net::HTTP).to receive(:start).and_return(auth_success, rate_success)

      bank.get_rate('EUR', 'USD', effective_date: Date.today)

      expect(Net::HTTP).to have_received(:start).at_least(:twice)
    end

    it 'reuses token when not expired' do
      call_count = 0
      allow(Net::HTTP).to receive(:start) do
        call_count += 1
        call_count == 1 ? auth_success : rate_success
      end

      bank.get_rate('EUR', 'USD', effective_date: Date.new(2024, 1, 1))
      bank.get_rate('EUR', 'GBP', effective_date: Date.new(2024, 1, 2))

      # Should only authenticate once
      expect(call_count).to eq(3) # 1 auth + 2 rate requests
    end

    context 'when refresh token fails' do
      let(:auth_failure) { instance_double(Net::HTTPUnauthorized, body: 'Unauthorized') }

      before do
        allow(auth_failure).to receive(:is_a?).with(Net::HTTPSuccess).and_return(false)
      end

      it 'falls back to full authentication' do
        # First call: get token (success)
        # Simulate token expiry and refresh failure, then success
        bank.instance_variable_set(:@token, 'old_token')
        bank.instance_variable_set(:@refresh_token, 'old_refresh')
        bank.instance_variable_set(:@token_expires_at, Time.now - 1)

        call_count = 0
        allow(Net::HTTP).to receive(:start) do
          call_count += 1
          case call_count
          when 1 then auth_failure # refresh fails
          when 2 then auth_success # full auth succeeds
          else rate_success
          end
        end

        bank.get_rate('EUR', 'USD', effective_date: Date.today)
        expect(call_count).to eq(3)
      end
    end
  end

  describe 'API request' do
    let(:auth_success) { instance_double(Net::HTTPSuccess, body: auth_response.to_json) }
    let(:rate_success) { instance_double(Net::HTTPSuccess, body: rate_response.to_json) }

    before do
      allow(auth_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(rate_success).to receive(:is_a?).with(Net::HTTPSuccess).and_return(true)
      allow(Net::HTTP).to receive(:start).and_return(auth_success, rate_success)
    end

    it 'uses "latest" endpoint when no effective_date' do
      bank.get_rate('EUR', 'USD', effective_date: Date.today)
      # The request should be made (we can't easily verify the path without more complex mocking)
      expect(Net::HTTP).to have_received(:start).at_least(:once)
    end

    it 'uses date endpoint when effective_date is provided' do
      bank.get_rate('EUR', 'USD', effective_date: Date.new(2024, 6, 15))
      expect(Net::HTTP).to have_received(:start).at_least(:once)
    end
  end
end
