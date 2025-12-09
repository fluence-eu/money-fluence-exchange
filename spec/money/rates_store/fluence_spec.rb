# frozen_string_literal: true

RSpec.describe Money::RatesStore::Fluence do
  subject(:store) { described_class.new }

  describe '#initialize' do
    it 'creates an empty store' do
      expect(store.each_rate.to_a).to be_empty
    end

    it 'accepts initial rates' do
      initial_rates = { 'EUR_TO_USD' => { Date.today => 1.12 } }
      store_with_rates = described_class.new({}, initial_rates)
      expect(store_with_rates.get_rate('EUR', 'USD')).to eq(1.12)
    end
  end

  describe '#add_rate' do
    it 'stores a rate for the current date by default' do
      store.add_rate('EUR', 'USD', 1.12)
      expect(store.get_rate('EUR', 'USD')).to eq(1.12)
    end

    it 'stores a rate for a specific effective date' do
      effective_date = Date.new(2024, 6, 15)
      store.add_rate('EUR', 'USD', 1.10, effective_date: effective_date)
      expect(store.get_rate('EUR', 'USD', effective_date: effective_date)).to eq(1.10)
    end

    it 'can store multiple rates for different dates' do
      date1 = Date.new(2024, 1, 1)
      date2 = Date.new(2024, 6, 1)

      store.add_rate('EUR', 'USD', 1.10, effective_date: date1)
      store.add_rate('EUR', 'USD', 1.15, effective_date: date2)

      expect(store.get_rate('EUR', 'USD', effective_date: date1)).to eq(1.10)
      expect(store.get_rate('EUR', 'USD', effective_date: date2)).to eq(1.15)
    end

    it 'overwrites existing rate for the same date' do
      store.add_rate('EUR', 'USD', 1.10)
      store.add_rate('EUR', 'USD', 1.15)
      expect(store.get_rate('EUR', 'USD')).to eq(1.15)
    end

    it 'returns the stored rate' do
      result = store.add_rate('EUR', 'USD', 1.12)
      expect(result).to eq(1.12)
    end
  end

  describe '#get_rate' do
    it 'retrieves rate for the current date by default' do
      store.add_rate('EUR', 'USD', 1.12)
      expect(store.get_rate('EUR', 'USD')).to eq(1.12)
    end

    it 'retrieves rate for a specific effective date' do
      effective_date = Date.new(2024, 6, 15)
      store.add_rate('EUR', 'USD', 1.10, effective_date: effective_date)
      expect(store.get_rate('EUR', 'USD', effective_date: effective_date)).to eq(1.10)
    end

    it 'returns nil for non-existent rate' do
      expect(store.get_rate('EUR', 'USD')).to be_nil
    end

    it 'returns nil for non-existent date' do
      store.add_rate('EUR', 'USD', 1.12, effective_date: Date.new(2024, 1, 1))
      expect(store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 6, 1))).to be_nil
    end
  end

  describe '#each_rate' do
    before do
      store.add_rate('EUR', 'USD', 1.12, effective_date: Date.new(2024, 1, 1))
      store.add_rate('EUR', 'GBP', 0.85, effective_date: Date.new(2024, 1, 1))
      store.add_rate('EUR', 'USD', 1.15, effective_date: Date.new(2024, 6, 1))
    end

    it 'returns an enumerator when no block is given' do
      expect(store.each_rate).to be_an(Enumerator)
    end

    it 'yields all rates with their metadata' do
      rates = []
      store.each_rate { |from, to, rate, date| rates << [from, to, rate, date] }

      expect(rates).to contain_exactly(
        ['EUR', 'USD', 1.12, Date.new(2024, 1, 1)],
        ['EUR', 'USD', 1.15, Date.new(2024, 6, 1)],
        ['EUR', 'GBP', 0.85, Date.new(2024, 1, 1)]
      )
    end

    it 'can be converted to an array' do
      result = store.each_rate.to_a
      expect(result.size).to eq(3)
    end
  end

  describe 'thread safety' do
    it 'handles concurrent writes safely' do
      threads = 10.times.map do |i|
        Thread.new do
          100.times do |j|
            store.add_rate('EUR', 'USD', i * 100 + j, effective_date: Date.today + j)
          end
        end
      end

      threads.each(&:join)

      # Should have 100 different dates (last write wins for each date)
      rates_count = store.each_rate.count
      expect(rates_count).to eq(100)
    end
  end
end
