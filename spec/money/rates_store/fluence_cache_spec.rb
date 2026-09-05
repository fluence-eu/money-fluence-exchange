# frozen_string_literal: true

RSpec.describe Money::RatesStore::FluenceCache do
  subject(:store) { described_class.new(cache) }

  let(:cache) { ActiveSupport::Cache::MemoryStore.new }

  describe '#add_rate' do
    it 'stores a rate for the current date by default' do
      store.add_rate('EUR', 'USD', 1.12)
      expect(store.get_rate('EUR', 'USD')).to eq(1.12)
    end

    it 'stores a rate for a specific effective date' do
      effective_date = Date.new(2024, 6, 15)
      store.add_rate('EUR', 'USD', 1.10, effective_date:)
      expect(store.get_rate('EUR', 'USD', effective_date:)).to eq(1.10)
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
      expect(store.add_rate('EUR', 'USD', 1.12)).to eq(1.12)
    end

    it 'keys a Money::Currency by its ISO code' do
      store.add_rate(Money::Currency.wrap('EUR'), Money::Currency.wrap('USD'), 1.12)
      expect(store.get_rate('EUR', 'USD')).to eq(1.12)
    end

    it 'writes under a key prefix of its own' do
      store.add_rate('EUR', 'USD', 1.12, effective_date: Date.new(2024, 6, 15))
      expect(cache.read('money-fluence-exchange/EUR_TO_USD/2024-06-15')).to eq(1.12)
    end
  end

  describe '#get_rate' do
    it 'returns nil for non-existent rate' do
      expect(store.get_rate('EUR', 'USD')).to be_nil
    end

    it 'returns nil for non-existent date' do
      store.add_rate('EUR', 'USD', 1.12, effective_date: Date.new(2024, 1, 1))
      expect(store.get_rate('EUR', 'USD', effective_date: Date.new(2024, 6, 1))).to be_nil
    end

    it 'ignores the case of currency codes' do
      store.add_rate('eur', 'usd', 1.12)
      expect(store.get_rate('EUR', 'USD')).to eq(1.12)
    end
  end

  describe '#each_rate' do
    it 'is not supported' do
      expect { store.each_rate }.to raise_error(NotImplementedError)
    end
  end

  describe '#marshal_dump' do
    it 'is not supported' do
      expect { Marshal.dump(store) }.to raise_error(NotImplementedError, /#{described_class}/)
    end
  end

  describe '#transaction' do
    it 'yields' do
      expect { |b| store.transaction(&b) }.to yield_control
    end
  end

  it 'shares its rates with every store on the same cache' do
    described_class.new(cache).add_rate('EUR', 'USD', 1.12)
    expect(store.get_rate('EUR', 'USD')).to eq(1.12)
  end
end
