# frozen_string_literal: true

RSpec.describe Money::Fluence::Exchange::Extension do
  let(:bank) { instance_double(Money::Bank::FluenceExchange) }
  let(:eur) { Money::Currency.find('EUR') }
  let(:usd) { Money::Currency.find('USD') }
  let(:cad) { Money::Currency.find('CAD') }
  let(:gbp) { Money::Currency.find('GBP') }
  let(:jpy) { Money::Currency.find('JPY') }

  # Create a test class that includes the Extension module
  let(:money_class) do
    Class.new do
      include Money::Fluence::Exchange::Extension

      attr_reader :currency, :bank, :fractional

      def initialize(fractional, currency, bank)
        @fractional = fractional
        @currency = Money::Currency.wrap(currency)
        @bank = bank
      end
    end
  end

  let(:money) { money_class.new(1000, 'EUR', bank) }

  describe '#exchange_to' do
    context 'when converting to a different currency' do
      it 'calls bank.exchange_with' do
        converted = money_class.new(1085, 'USD', bank)
        expect(bank).to receive(:exchange_with).with(money, usd).and_return(converted)

        result = money.exchange_to('USD')
        expect(result).to eq(converted)
      end

      it 'passes effective_date option to bank' do
        date = Date.new(2024, 1, 15)
        converted = money_class.new(1050, 'USD', bank)
        expect(bank).to receive(:exchange_with).with(money, usd, effective_date: date).and_return(converted)

        money.exchange_to('USD', effective_date: date)
      end

      it 'passes rounding_method block to bank' do
        converted = money_class.new(1085, 'USD', bank)
        block_called = false
        rounding_block = proc { block_called = true }

        expect(bank).to receive(:exchange_with) do |m, c, &block|
          expect(m).to eq(money)
          expect(c).to eq(usd)
          expect(block).not_to be_nil
          block.call
          converted
        end

        money.exchange_to('USD', &rounding_block)
        expect(block_called).to be true
      end
    end

    context 'when converting to the same currency' do
      it 'returns self without calling bank' do
        expect(bank).not_to receive(:exchange_with)

        result = money.exchange_to('EUR')
        expect(result).to be(money)
      end
    end

    it 'accepts currency as Symbol' do
      converted = money_class.new(1085, 'USD', bank)
      expect(bank).to receive(:exchange_with).with(money, usd).and_return(converted)

      money.exchange_to(:usd)
    end

    it 'accepts currency as Currency object' do
      converted = money_class.new(1085, 'USD', bank)
      expect(bank).to receive(:exchange_with).with(money, usd).and_return(converted)

      money.exchange_to(usd)
    end
  end

  describe '#to_money' do
    context 'when given_currency is nil' do
      it 'returns self' do
        expect(bank).not_to receive(:exchange_with)

        result = money.to_money(nil)
        expect(result).to be(money)
      end
    end

    context 'when given_currency matches current currency' do
      it 'returns self' do
        expect(bank).not_to receive(:exchange_with)

        result = money.to_money('EUR')
        expect(result).to be(money)
      end
    end

    context 'when given_currency is different' do
      it 'calls exchange_to' do
        converted = money_class.new(1085, 'USD', bank)
        expect(bank).to receive(:exchange_with).with(money, usd).and_return(converted)

        result = money.to_money('USD')
        expect(result).to eq(converted)
      end

      it 'passes effective_date option' do
        date = Date.new(2024, 6, 1)
        converted = money_class.new(1050, 'USD', bank)
        expect(bank).to receive(:exchange_with).with(money, usd, effective_date: date).and_return(converted)

        money.to_money('USD', effective_date: date)
      end

      it 'passes rounding_method block' do
        converted = money_class.new(1085, 'USD', bank)
        block_called = false
        rounding_block = proc { block_called = true }

        expect(bank).to receive(:exchange_with) do |_m, _c, &block|
          expect(block).not_to be_nil
          block.call
          converted
        end

        money.to_money('USD', &rounding_block)
        expect(block_called).to be true
      end
    end
  end

  describe '#as_us_dollar' do
    it 'converts to USD' do
      converted = money_class.new(1085, 'USD', bank)
      expect(bank).to receive(:exchange_with).with(money, usd).and_return(converted)

      result = money.as_us_dollar
      expect(result).to eq(converted)
    end

    it 'passes effective_date option' do
      date = Date.new(2024, 1, 15)
      converted = money_class.new(1050, 'USD', bank)
      expect(bank).to receive(:exchange_with).with(money, usd, effective_date: date).and_return(converted)

      money.as_us_dollar(effective_date: date)
    end

    it 'passes rounding_method block' do
      converted = money_class.new(1085, 'USD', bank)
      block_called = false
      rounding_block = proc { block_called = true }

      expect(bank).to receive(:exchange_with) do |_m, _c, &block|
        expect(block).not_to be_nil
        block.call
        converted
      end

      money.as_us_dollar(&rounding_block)
      expect(block_called).to be true
    end
  end

  describe '#as_ca_dollar' do
    it 'converts to CAD' do
      converted = money_class.new(1450, 'CAD', bank)
      expect(bank).to receive(:exchange_with).with(money, cad).and_return(converted)

      result = money.as_ca_dollar
      expect(result).to eq(converted)
    end

    it 'passes effective_date option' do
      date = Date.new(2024, 1, 15)
      converted = money_class.new(1400, 'CAD', bank)
      expect(bank).to receive(:exchange_with).with(money, cad, effective_date: date).and_return(converted)

      money.as_ca_dollar(effective_date: date)
    end
  end

  describe '#as_euro' do
    let(:money) { money_class.new(1000, 'USD', bank) }

    it 'converts to EUR' do
      converted = money_class.new(920, 'EUR', bank)
      expect(bank).to receive(:exchange_with).with(money, eur).and_return(converted)

      result = money.as_euro
      expect(result).to eq(converted)
    end

    it 'passes effective_date option' do
      date = Date.new(2024, 1, 15)
      converted = money_class.new(900, 'EUR', bank)
      expect(bank).to receive(:exchange_with).with(money, eur, effective_date: date).and_return(converted)

      money.as_euro(effective_date: date)
    end
  end

  describe 'dynamic as_XXX methods via method_missing' do
    describe '#as_gbp' do
      it 'converts to GBP' do
        converted = money_class.new(860, 'GBP', bank)
        expect(bank).to receive(:exchange_with).with(money, gbp).and_return(converted)

        result = money.as_gbp
        expect(result).to eq(converted)
      end

      it 'passes effective_date option' do
        date = Date.new(2024, 1, 15)
        converted = money_class.new(850, 'GBP', bank)
        expect(bank).to receive(:exchange_with).with(money, gbp, effective_date: date).and_return(converted)

        money.as_gbp(effective_date: date)
      end

      it 'passes rounding_method block' do
        converted = money_class.new(860, 'GBP', bank)
        block_called = false
        rounding_block = proc { block_called = true }

        expect(bank).to receive(:exchange_with) do |_m, _c, &block|
          expect(block).not_to be_nil
          block.call
          converted
        end

        money.as_gbp(&rounding_block)
        expect(block_called).to be true
      end
    end

    describe '#as_jpy' do
      it 'converts to JPY' do
        converted = money_class.new(160_000, 'JPY', bank)
        expect(bank).to receive(:exchange_with).with(money, jpy).and_return(converted)

        result = money.as_jpy
        expect(result).to eq(converted)
      end
    end

    it 'raises NoMethodError for unknown currency' do
      expect { money.as_xyz }.to raise_error(NoMethodError)
    end

    it 'raises NoMethodError for non as_ methods' do
      expect { money.foo_bar }.to raise_error(NoMethodError)
    end
  end

  describe '#respond_to_missing?' do
    it 'returns true for valid currency codes' do
      expect(money.respond_to?(:as_gbp)).to be true
      expect(money.respond_to?(:as_jpy)).to be true
      expect(money.respond_to?(:as_chf)).to be true
    end

    it 'returns false for invalid currency codes' do
      expect(money.respond_to?(:as_xyz)).to be false
      expect(money.respond_to?(:as_abc)).to be false
    end

    it 'returns false for non as_ methods' do
      expect(money.respond_to?(:foo_bar)).to be false
    end

    it 'returns true for explicitly defined methods' do
      expect(money.respond_to?(:as_us_dollar)).to be true
      expect(money.respond_to?(:as_ca_dollar)).to be true
      expect(money.respond_to?(:as_euro)).to be true
      expect(money.respond_to?(:exchange_to)).to be true
      expect(money.respond_to?(:to_money)).to be true
    end
  end
end
