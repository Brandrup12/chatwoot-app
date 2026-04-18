require 'rails_helper'

RSpec.describe Integrations::App do
  let(:apps) { described_class }
  let(:app) { apps.find(id: app_name) }
  let(:account) { create(:account) }

  describe '#name' do
    let(:app_name) { 'slack' }

    it 'returns the name' do
      expect(app.name).to eq('Slack')
    end
  end

  describe '#logo' do
    let(:app_name) { 'slack' }

    it 'returns the logo' do
      expect(app.logo).to eq('slack.png')
    end
  end

  describe '#active?' do
    let(:app_name) { 'shopify' }

    context 'when the app is shopify' do
      let(:app_name) { 'shopify' }

      it 'returns true if the shopify integration feature is enabled' do
        account.enable_features('shopify_integration')
        allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil).and_return('client_id')
        expect(app.active?(account)).to be true
      end

      it 'returns false if the shopify integration feature is disabled' do
        allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil).and_return('client_id')
        expect(app.active?(account)).to be false
      end

      it 'returns false if SHOPIFY_CLIENT_ID is not present, even if feature is enabled' do
        account.enable_features('shopify_integration')
        allow(GlobalConfigService).to receive(:load).with('SHOPIFY_CLIENT_ID', nil).and_return(nil)
        expect(app.active?(account)).to be false
      end
    end

    context 'when other apps are queried' do
      let(:app_name) { 'webhook' }

      it 'returns true' do
        expect(app.active?(account)).to be true
      end
    end
  end

  describe '#enabled?' do
    context 'when the app is webhook' do
      let(:app_name) { 'webhook' }

      it 'returns false if the account does not have any webhooks' do
        expect(app.enabled?(account)).to be false
      end

      it 'returns true if the account has webhooks' do
        create(:webhook, account: account)
        expect(app.enabled?(account)).to be true
      end
    end

  end
end
