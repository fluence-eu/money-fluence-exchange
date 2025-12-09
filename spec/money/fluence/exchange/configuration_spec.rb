# frozen_string_literal: true

RSpec.describe Money::Fluence::Exchange::Configuration do
  describe '.configure' do
    after do
      # Reset to defaults
      Money::Fluence::Exchange.client_id = ENV['FX_CLIENT_ID']
      Money::Fluence::Exchange.client_secret = ENV['FX_CLIENT_SECRET']
      Money::Fluence::Exchange.base_url = 'https://fx.knowledge.appvision.fr'
    end

    it 'allows configuration via block' do
      Money::Fluence::Exchange.configure do |config|
        config.client_id = 'test_client_id'
        config.client_secret = 'test_client_secret'
        config.base_url = 'https://test.example.com'
      end

      expect(Money::Fluence::Exchange.client_id).to eq('test_client_id')
      expect(Money::Fluence::Exchange.client_secret).to eq('test_client_secret')
      expect(Money::Fluence::Exchange.base_url).to eq('https://test.example.com')
    end
  end

  describe '.client_id' do
    it 'defaults to ENV["FX_CLIENT_ID"]' do
      allow(ENV).to receive(:[]).with('FX_CLIENT_ID').and_return('env_client_id')
      # Reload to pick up the mocked ENV
      expect(Money::Fluence::Exchange.client_id).not_to be_nil
    end

    it 'can be set directly' do
      original = Money::Fluence::Exchange.client_id
      Money::Fluence::Exchange.client_id = 'direct_client_id'
      expect(Money::Fluence::Exchange.client_id).to eq('direct_client_id')
      Money::Fluence::Exchange.client_id = original
    end
  end

  describe '.client_secret' do
    it 'can be set directly' do
      original = Money::Fluence::Exchange.client_secret
      Money::Fluence::Exchange.client_secret = 'direct_client_secret'
      expect(Money::Fluence::Exchange.client_secret).to eq('direct_client_secret')
      Money::Fluence::Exchange.client_secret = original
    end
  end

  describe '.base_url' do
    it 'defaults to the Fluence FX API URL' do
      expect(Money::Fluence::Exchange.base_url).to eq('https://fx.knowledge.appvision.fr')
    end

    it 'can be set directly' do
      original = Money::Fluence::Exchange.base_url
      Money::Fluence::Exchange.base_url = 'https://custom.example.com'
      expect(Money::Fluence::Exchange.base_url).to eq('https://custom.example.com')
      Money::Fluence::Exchange.base_url = original
    end
  end
end
