require 'rails_helper'

RSpec.describe 'Google::CallbacksController', type: :request do
  let(:account) { create(:account) }
  let(:code) { SecureRandom.hex(10) }
  let(:email) { Faker::Internet.email }
  let(:state) { account.to_sgid(expires_in: 15.minutes).to_s }

  describe 'GET /google/callback' do
    let(:response_body_success) do
      { id_token: JWT.encode({ email: email, name: 'test' }, false), access_token: SecureRandom.hex(10), token_type: 'Bearer',
        refresh_token: SecureRandom.hex(10) }
    end

    let(:response_body_success_without_name) do
      { id_token: JWT.encode({ email: email }, false), access_token: SecureRandom.hex(10), token_type: 'Bearer',
        refresh_token: SecureRandom.hex(10) }
    end

    it 'redirects to google app in case of error' do
      stub_request(:post, 'https://accounts.google.com/o/oauth2/token')
        .with(body: { 'code' => code, 'grant_type' => 'authorization_code',
                      'redirect_uri' => "#{ENV.fetch('FRONTEND_URL', 'http://localhost:3000')}/google/callback" })
        .to_return(status: 401)

      get google_callback_url, params: { code: code, state: state }

      expect(response).to redirect_to '/'
    end
  end
end
