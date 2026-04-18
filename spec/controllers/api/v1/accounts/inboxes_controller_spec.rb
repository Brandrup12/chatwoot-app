require 'rails_helper'

RSpec.describe 'Inboxes API', type: :request do
  include ActiveJob::TestHelper

  let(:account) { create(:account) }
  let(:agent) { create(:user, account: account, role: :agent) }
  let(:admin) { create(:user, account: account, role: :administrator) }

  describe 'GET /api/v1/accounts/{account.id}/inboxes' do
    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:admin) { create(:user, account: account, role: :administrator) }
      let(:inbox) { create(:inbox, account: account) }

      before do
        create(:inbox, account: account)
        create(:inbox_member, user: agent, inbox: inbox)
      end


      context 'when provider_config' do
        let(:inbox) { create(:channel_whatsapp, account: account, sync_templates: false, validate_provider_config: false).inbox }

        it 'returns provider config attributes for admin' do
          get "/api/v1/accounts/#{account.id}/inboxes",
              headers: admin.create_new_auth_token,
              as: :json
          expect(response.body).to include('provider_config')
        end

        it 'will not return provider config for agent' do
          get "/api/v1/accounts/#{account.id}/inboxes",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response.body).not_to include('provider_config')
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:agent) { create(:user, account: account, role: :agent) }
      let(:admin) { create(:user, account: account, role: :administrator) }
      let(:inbox) { create(:inbox, account: account) }

      it 'returns unauthorized for an agent who is not assigned' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:unauthorized)
      end

    end
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/assignable_agents' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/assignable_agents"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      before do
        create(:inbox_member, user: agent, inbox: inbox)
      end

      it 'returns all assignable inbox members along with administrators' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/assignable_agents",
            headers: admin.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        response_data = JSON.parse(response.body, symbolize_names: true)[:payload]
        expect(response_data.size).to eq(2)
        expect(response_data.pluck(:role)).to include('agent', 'administrator')
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/inboxes/{inbox.id}/avatar' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/avatar"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      before do
        create(:inbox_member, user: agent, inbox: inbox)
        inbox.avatar.attach(io: Rails.root.join('spec/assets/avatar.png').open, filename: 'avatar.png', content_type: 'image/png')
      end

      it 'delete inbox avatar for administrator user' do
        perform_enqueued_jobs(only: DeleteObjectJob) do
          delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/avatar",
                 headers: admin.create_new_auth_token,
                 as: :json
        end

        expect { inbox.avatar.attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(response).to have_http_status(:success)
      end

      it 'returns unauthorized for agent user' do
        delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/avatar",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'DELETE /api/v1/accounts/{account.id}/inboxes/:id' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }

      it 'deletes inbox' do
        expect(DeleteObjectJob).to receive(:perform_later).with(inbox, admin, anything).once

        perform_enqueued_jobs(only: DeleteObjectJob) do
          delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
                 headers: admin.create_new_auth_token,
                 as: :json
        end

        json_response = response.parsed_body

        expect(response).to have_http_status(:success)
        expect(json_response['message']).to eq('Your inbox deletion request will be processed in some time.')
      end

      it 'is unable to delete inbox of another account' do
        other_account = create(:account)
        other_inbox = create(:inbox, account: other_account)

        delete "/api/v1/accounts/#{account.id}/inboxes/#{other_inbox.id}",
               headers: admin.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'is unable to delete inbox as agent' do
        agent = create(:user, account: account, role: :agent)

        delete "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}",
               headers: agent.create_new_auth_token,
               as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }
      let(:valid_params) { { name: 'test', channel: { type: 'web_widget', website_url: 'test.com' } } }

      it 'will not create inbox for agent' do
        agent = create(:user, account: account, role: :agent)

        post "/api/v1/accounts/#{account.id}/inboxes",
             headers: agent.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end

    end
  end

  describe 'PATCH /api/v1/accounts/{account.id}/inboxes/:id' do
    let(:inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        patch "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}"

        expect(response).to have_http_status(:unauthorized)
      end
    end

  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/agent_bot' do
    let(:inbox) { create(:inbox, account: account) }

    before do
      create(:inbox_member, user: agent, inbox: inbox)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/agent_bot"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      it 'returns empty when no agent bot is present' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/agent_bot",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        inbox_data = JSON.parse(response.body, symbolize_names: true)
        expect(inbox_data[:agent_bot].blank?).to be(true)
      end

      it 'returns the agent bot attached to the inbox' do
        agent_bot = create(:agent_bot)
        create(:agent_bot_inbox, agent_bot: agent_bot, inbox: inbox)
        get "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/agent_bot",
            headers: agent.create_new_auth_token,
            as: :json

        expect(response).to have_http_status(:success)
        inbox_data = JSON.parse(response.body, symbolize_names: true)
        expect(inbox_data[:agent_bot][:name]).to eq agent_bot.name
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/:id/set_agent_bot' do
    let(:inbox) { create(:inbox, account: account) }
    let(:agent_bot) { create(:agent_bot) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/set_agent_bot"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      let(:admin) { create(:user, account: account, role: :administrator) }
      let(:valid_params) { { agent_bot: agent_bot.id } }

      it 'sets the agent bot' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/set_agent_bot",
             headers: admin.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:success)
        expect(inbox.reload.agent_bot.id).to eq agent_bot.id
      end

      it 'throw error when invalid agent bot id' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/set_agent_bot",
             headers: admin.create_new_auth_token,
             params: { agent_bot: 0 },
             as: :json

        expect(response).to have_http_status(:not_found)
      end

      it 'disconnects the agent bot' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/set_agent_bot",
             headers: admin.create_new_auth_token,
             params: { agent_bot: nil },
             as: :json

        expect(response).to have_http_status(:success)
        expect(inbox.reload.agent_bot).to be_falsey
      end

      it 'will not update agent bot when its an agent' do
        agent = create(:user, account: account, role: :agent)

        post "/api/v1/accounts/#{account.id}/inboxes/#{inbox.id}/set_agent_bot",
             headers: agent.create_new_auth_token,
             params: valid_params,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe 'POST /api/v1/accounts/{account.id}/inboxes/:id/sync_templates' do
    let(:whatsapp_channel) do
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    end
    let(:whatsapp_inbox) { create(:inbox, account: account, channel: whatsapp_channel) }
    let(:non_whatsapp_inbox) { create(:inbox, account: account) }

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/sync_templates"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated agent' do
      it 'returns unauthorized for agent' do
        post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/sync_templates",
             headers: agent.create_new_auth_token,
             as: :json

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated administrator' do
      context 'with WhatsApp inbox' do
        it 'successfully initiates template sync' do
          expect(Channels::Whatsapp::TemplatesSyncJob).to receive(:perform_later).with(whatsapp_channel)

          post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/sync_templates",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body
          expect(json_response['message']).to eq('Template sync initiated successfully')
        end

        it 'handles job errors gracefully' do
          allow(Channels::Whatsapp::TemplatesSyncJob).to receive(:perform_later).and_raise(StandardError, 'Job failed')

          post "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/sync_templates",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:internal_server_error)
          json_response = response.parsed_body
          expect(json_response['error']).to eq('Job failed')
        end
      end

      context 'with non-WhatsApp inbox' do
        it 'returns unprocessable entity error' do
          post "/api/v1/accounts/#{account.id}/inboxes/#{non_whatsapp_inbox.id}/sync_templates",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body
          expect(json_response['error']).to eq('Template sync is only available for WhatsApp channels')
        end
      end

      context 'with non-existent inbox' do
        it 'returns not found error' do
          post "/api/v1/accounts/#{account.id}/inboxes/999999/sync_templates",
               headers: admin.create_new_auth_token,
               as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end

  describe 'GET /api/v1/accounts/{account.id}/inboxes/{inbox.id}/health' do
    let(:whatsapp_channel) do
      create(:channel_whatsapp, account: account, provider: 'whatsapp_cloud', sync_templates: false, validate_provider_config: false)
    end
    let(:whatsapp_inbox) { create(:inbox, account: account, channel: whatsapp_channel) }
    let(:non_whatsapp_inbox) { create(:inbox, account: account) }
    let(:health_service) { instance_double(Whatsapp::HealthService) }
    let(:health_data) do
      {
        display_phone_number: '+1234567890',
        verified_name: 'Test Business',
        name_status: 'APPROVED',
        quality_rating: 'GREEN',
        messaging_limit_tier: 'TIER_1000',
        account_mode: 'LIVE',
        business_id: 'business123'
      }
    end

    before do
      allow(Whatsapp::HealthService).to receive(:new).and_return(health_service)
      allow(health_service).to receive(:fetch_health_status).and_return(health_data)
    end

    context 'when it is an unauthenticated user' do
      it 'returns unauthorized' do
        get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context 'when it is an authenticated user' do
      context 'with WhatsApp inbox' do
        it 'returns health data for administrator' do
          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body
          expect(json_response).to include(
            'display_phone_number' => '+1234567890',
            'verified_name' => 'Test Business',
            'name_status' => 'APPROVED',
            'quality_rating' => 'GREEN',
            'messaging_limit_tier' => 'TIER_1000',
            'account_mode' => 'LIVE',
            'business_id' => 'business123'
          )
        end

        it 'returns health data for agent with inbox access' do
          create(:inbox_member, user: agent, inbox: whatsapp_inbox)

          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
          json_response = response.parsed_body
          expect(json_response['display_phone_number']).to eq('+1234567890')
        end

        it 'returns unauthorized for agent without inbox access' do
          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:unauthorized)
        end

        it 'calls the health service with correct channel' do
          expect(Whatsapp::HealthService).to receive(:new).with(whatsapp_channel).and_return(health_service)
          expect(health_service).to receive(:fetch_health_status)

          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:success)
        end

        it 'handles service errors gracefully' do
          allow(health_service).to receive(:fetch_health_status).and_raise(StandardError, 'API Error')

          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_inbox.id}/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:unprocessable_entity)
          json_response = response.parsed_body
          expect(json_response['error']).to include('API Error')
        end
      end

      context 'with non-WhatsApp inbox' do
        it 'returns bad request error for administrator' do
          get "/api/v1/accounts/#{account.id}/inboxes/#{non_whatsapp_inbox.id}/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:bad_request)
          json_response = response.parsed_body
          expect(json_response['error']).to eq('Health data only available for WhatsApp Cloud API channels')
        end

        it 'returns bad request error for agent' do
          create(:inbox_member, user: agent, inbox: non_whatsapp_inbox)

          get "/api/v1/accounts/#{account.id}/inboxes/#{non_whatsapp_inbox.id}/health",
              headers: agent.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:bad_request)
          json_response = response.parsed_body
          expect(json_response['error']).to eq('Health data only available for WhatsApp Cloud API channels')
        end
      end

      context 'with WhatsApp non-cloud inbox' do
        let(:whatsapp_default_channel) do
          create(:channel_whatsapp, account: account, provider: 'default', sync_templates: false, validate_provider_config: false)
        end
        let(:whatsapp_default_inbox) { create(:inbox, account: account, channel: whatsapp_default_channel) }

        it 'returns bad request error for non-cloud provider' do
          get "/api/v1/accounts/#{account.id}/inboxes/#{whatsapp_default_inbox.id}/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:bad_request)
          json_response = response.parsed_body
          expect(json_response['error']).to eq('Health data only available for WhatsApp Cloud API channels')
        end
      end

      context 'with non-existent inbox' do
        it 'returns not found error' do
          get "/api/v1/accounts/#{account.id}/inboxes/999999/health",
              headers: admin.create_new_auth_token,
              as: :json

          expect(response).to have_http_status(:not_found)
        end
      end
    end
  end
end
